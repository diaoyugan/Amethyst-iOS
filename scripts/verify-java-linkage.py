#!/usr/bin/env python3
"""Verify that bytecode member references can be resolved by a provider JAR."""

import argparse
import struct
import sys
import zipfile
from dataclasses import dataclass
from typing import Dict, Iterable, List, Optional, Set, Tuple


class ClassFormatError(Exception):
    pass


class Reader:
    def __init__(self, data: bytes):
        self.data = data
        self.offset = 0

    def read(self, size: int) -> bytes:
        end = self.offset + size
        if end > len(self.data):
            raise ClassFormatError("unexpected end of class file")
        value = self.data[self.offset:end]
        self.offset = end
        return value

    def u1(self) -> int:
        return self.read(1)[0]

    def u2(self) -> int:
        return struct.unpack(">H", self.read(2))[0]

    def u4(self) -> int:
        return struct.unpack(">I", self.read(4))[0]


@dataclass
class ClassInfo:
    name: str
    super_name: Optional[str]
    interfaces: Tuple[str, ...]
    fields: Set[Tuple[str, str]]
    methods: Set[Tuple[str, str]]


MemberRef = Tuple[str, str, str, str]

EXTERNAL_METHODS = {
    "java/lang/Object": {
        ("equals", "(Ljava/lang/Object;)Z"),
        ("getClass", "()Ljava/lang/Class;"),
        ("hashCode", "()I"),
        ("notify", "()V"),
        ("notifyAll", "()V"),
        ("toString", "()Ljava/lang/String;"),
        ("wait", "()V"),
        ("wait", "(J)V"),
        ("wait", "(JI)V"),
    },
    "java/lang/Enum": {
        ("compareTo", "(Ljava/lang/Enum;)I"),
        ("equals", "(Ljava/lang/Object;)Z"),
        ("getDeclaringClass", "()Ljava/lang/Class;"),
        ("hashCode", "()I"),
        ("name", "()Ljava/lang/String;"),
        ("ordinal", "()I"),
        ("toString", "()Ljava/lang/String;"),
    },
}


def parse_class(data: bytes) -> Tuple[ClassInfo, Set[MemberRef]]:
    reader = Reader(data)
    if reader.u4() != 0xCAFEBABE:
        raise ClassFormatError("invalid class file magic")
    reader.read(4)  # minor_version, major_version

    constant_pool: List[Optional[Tuple]] = [None] * reader.u2()
    index = 1
    while index < len(constant_pool):
        tag = reader.u1()
        if tag == 1:
            length = reader.u2()
            constant_pool[index] = ("utf8", reader.read(length).decode("utf-8", "replace"))
        elif tag in (3, 4):
            reader.read(4)
        elif tag in (5, 6):
            reader.read(8)
            index += 1
        elif tag == 7:
            constant_pool[index] = ("class", reader.u2())
        elif tag == 8:
            reader.read(2)
        elif tag in (9, 10, 11):
            constant_pool[index] = (
                "field" if tag == 9 else "method",
                reader.u2(),
                reader.u2(),
            )
        elif tag == 12:
            constant_pool[index] = ("name_and_type", reader.u2(), reader.u2())
        elif tag == 15:
            reader.read(3)
        elif tag in (16, 19, 20):
            reader.read(2)
        elif tag in (17, 18):
            reader.read(4)
        else:
            raise ClassFormatError(f"unsupported constant-pool tag {tag}")
        index += 1

    def utf8(cp_index: int) -> str:
        entry = constant_pool[cp_index]
        if entry is None or entry[0] != "utf8":
            raise ClassFormatError(f"constant-pool entry {cp_index} is not UTF-8")
        return entry[1]

    def class_name(cp_index: int) -> str:
        if cp_index == 0:
            return ""
        entry = constant_pool[cp_index]
        if entry is None or entry[0] != "class":
            raise ClassFormatError(f"constant-pool entry {cp_index} is not a class")
        return utf8(entry[1])

    def skip_attributes() -> None:
        for _ in range(reader.u2()):
            reader.read(2)
            reader.read(reader.u4())

    def read_members() -> Set[Tuple[str, str]]:
        members: Set[Tuple[str, str]] = set()
        for _ in range(reader.u2()):
            reader.read(2)  # access_flags
            name = utf8(reader.u2())
            descriptor = utf8(reader.u2())
            members.add((name, descriptor))
            skip_attributes()
        return members

    reader.read(2)  # access_flags
    this_name = class_name(reader.u2())
    super_name = class_name(reader.u2()) or None
    interfaces = tuple(class_name(reader.u2()) for _ in range(reader.u2()))
    fields = read_members()
    methods = read_members()

    references: Set[MemberRef] = set()
    for entry in constant_pool:
        if entry is None or entry[0] not in ("field", "method"):
            continue
        owner = class_name(entry[1])
        name_and_type = constant_pool[entry[2]]
        if name_and_type is None or name_and_type[0] != "name_and_type":
            raise ClassFormatError("invalid member reference")
        references.add((entry[0], owner, utf8(name_and_type[1]), utf8(name_and_type[2])))

    return ClassInfo(this_name, super_name, interfaces, fields, methods), references


def iter_classes(jar_path: str) -> Iterable[Tuple[str, bytes]]:
    with zipfile.ZipFile(jar_path) as jar:
        for entry in jar.infolist():
            if not entry.filename.endswith(".class"):
                continue
            if entry.filename.startswith("META-INF/versions/"):
                continue
            yield entry.filename, jar.read(entry)


def load_provider(jar_path: str) -> Dict[str, ClassInfo]:
    classes: Dict[str, ClassInfo] = {}
    for entry_name, data in iter_classes(jar_path):
        try:
            class_info, _ = parse_class(data)
        except ClassFormatError as error:
            raise ClassFormatError(f"{entry_name}: {error}") from error
        classes[class_info.name] = class_info
    return classes


def load_references(jar_path: str, prefix: str) -> Set[MemberRef]:
    references: Set[MemberRef] = set()
    for entry_name, data in iter_classes(jar_path):
        try:
            _, class_references = parse_class(data)
        except ClassFormatError as error:
            raise ClassFormatError(f"{entry_name}: {error}") from error
        references.update(ref for ref in class_references if ref[1].startswith(prefix))
    return references


def resolves(
    classes: Dict[str, ClassInfo],
    kind: str,
    owner: str,
    name: str,
    descriptor: str,
    visited: Optional[Set[str]] = None,
) -> bool:
    class_info = classes.get(owner)
    if class_info is None:
        return kind == "method" and (name, descriptor) in EXTERNAL_METHODS.get(owner, set())

    members = class_info.fields if kind == "field" else class_info.methods
    if (name, descriptor) in members:
        return True
    if name in ("<init>", "<clinit>"):
        return False

    if visited is None:
        visited = set()
    if owner in visited:
        return False
    visited.add(owner)

    parents = list(class_info.interfaces)
    if class_info.super_name is not None:
        parents.append(class_info.super_name)
    return any(
        resolves(classes, kind, parent, name, descriptor, visited)
        for parent in parents
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--consumer", required=True, help="JAR containing bytecode references")
    parser.add_argument("--provider", required=True, help="JAR expected to satisfy the references")
    parser.add_argument(
        "--prefix",
        default="org/lwjgl/",
        help="internal class-name prefix to verify (default: org/lwjgl/)",
    )
    args = parser.parse_args()

    try:
        classes = load_provider(args.provider)
        references = load_references(args.consumer, args.prefix)
    except (ClassFormatError, OSError, zipfile.BadZipFile) as error:
        print(f"linkage verification failed: {error}", file=sys.stderr)
        return 2

    missing = sorted(
        reference
        for reference in references
        if not resolves(classes, *reference)
    )
    print(
        f"Checked {len(references)} unique {args.prefix} member references "
        f"against {len(classes)} provider classes."
    )
    if missing:
        print(f"Missing {len(missing)} member(s):", file=sys.stderr)
        for kind, owner, name, descriptor in missing:
            print(f"  {kind} {owner}.{name}:{descriptor}", file=sys.stderr)
        return 1

    print("All referenced members resolve.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
