"""Validated shapes for every file the runner reads or writes."""

from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class Strict(BaseModel):
    model_config = ConfigDict(extra="forbid")


class VersionCheck(Strict):
    source: Literal["dockerhub", "github-tags", "mcr"]
    repo: str
    name_hint: str = ""
    tag_regex: str


class Toolchain(Strict):
    id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]*$")
    lang: str
    config: str
    compiler: str
    version: str
    image: str
    version_command: str | None = None
    build: str | None = None
    run_cmd: str | None = None
    env: dict[str, str] = Field(default_factory=dict)
    setup: list[str] = Field(default_factory=list)
    image_setup: list[str] = Field(default_factory=list)
    cache_dirs: list[str] = Field(default_factory=list)
    exclude_profiles: list[str] = Field(default_factory=list)
    check: VersionCheck | None = None

    def fill(self, text: str) -> str:
        return text.replace("{version}", self.version)

    @property
    def image_ref(self) -> str:
        return self.fill(self.image)


class ToolchainFile(Strict):
    toolchains: list[Toolchain]

    @field_validator("toolchains")
    @classmethod
    def unique_ids(cls, value: list[Toolchain]) -> list[Toolchain]:
        ids = [t.id for t in value]
        if len(ids) != len(set(ids)):
            raise ValueError("toolchain ids must be unique")
        return value


class Profile(Strict):
    id: str = Field(pattern=r"^[a-z0-9][a-z0-9-]*$")
    name: str
    cpuset_single: str = Field(pattern=r"^[0-9,-]+$")
    cpuset_multi: str = Field(pattern=r"^[0-9,-]+$")
    memory_mb: int = Field(gt=256)
    warmup: int = Field(ge=0, le=5)
    repeats: int = Field(ge=1, le=20)
    timeout_s: int = Field(ge=1, le=600)
    inputs: Literal["all", "largest"]
    env: dict[str, str] = Field(default_factory=dict)


class ProfileFile(Strict):
    profiles: list[Profile]


class Upstream(Strict):
    repo: str
    commit: str = Field(pattern=r"^[0-9a-f]{40}$")
    license: str


# Upstream YAML: unknown keys are tolerated because the upstream project owns the format.


class Loose(BaseModel):
    model_config = ConfigDict(extra="ignore")


class UnitTest(Loose):
    input: str
    output: str

    @field_validator("input", "output", mode="before")
    @classmethod
    def stringify(cls, value: object) -> str:
        return str(value)


class BenchInput(Loose):
    input: str

    @field_validator("input", mode="before")
    @classmethod
    def stringify(cls, value: object) -> str:
        return str(value)


class ProblemSpec(Loose):
    name: str
    data: list[str] = Field(default_factory=list)
    unittests: list[UnitTest] = Field(default_factory=list)
    tests: list[BenchInput] = Field(default_factory=list)


class BenchFile(Loose):
    problems: list[ProblemSpec]


class LangProblem(Loose):
    name: str
    source: list[str] = Field(default_factory=list)


class Environment(Loose):
    compiler: str
    version: str | int | None = None
    enabled: bool = True
    include: str | None = None
    include_sub_dir: str | None = None
    before_build: list[str] = Field(default_factory=list)
    build: str
    after_build: list[str] = Field(default_factory=list)
    out_dir: str
    run_cmd: str
    env: dict[str, str] = Field(default_factory=dict)

    @field_validator("env", mode="before")
    @classmethod
    def env_strings(cls, value: object) -> dict[str, str]:
        if not isinstance(value, dict):
            return {}
        return {str(k): str(v) for k, v in value.items()}


class LangFile(Loose):
    lang: str
    source_rename_to: str
    problems: list[LangProblem]
    environments: list[Environment]


# Files produced by the runner.

Status = Literal["ok", "fail", "build-fail", "timeout", "oom", "wrong-output"]


class BuildEntry(Strict):
    problem: str
    source: str
    path: str
    out_dir: str
    run_cmd: str
    status: Literal["ok", "build-fail"]
    build_ms: int


class BuildManifest(Strict):
    toolchain: str
    image: str
    compiler: str
    version: str
    version_detail: str
    arch: str
    entries: list[BuildEntry]


class Machine(Strict):
    profile: str
    cpu: str
    cores: int
    memory_mb: int
    os: str
    arch: str


class ResultRow(Strict):
    problem: str
    input: str
    input_index: int
    lang: str
    compiler: str
    version: str
    code: str
    flags: list[str]
    status: Status
    time_ms: float | None = None
    stddev_ms: float | None = None
    user_ms: float | None = None
    sys_ms: float | None = None
    peak_mem_mb: float | None = None
    measured_at: str


class Run(Strict):
    id: str
    profile: str
    source: Literal["runner", "import"]
    started_at: str
    upstream_commit: str | None
    machine: Machine
    rows: list[ResultRow]


class RunIndexEntry(Strict):
    id: str
    profile: str
    started_at: str
    source: Literal["runner", "import"]
    rows: int


class ProfileSummary(Strict):
    id: str
    name: str
    latest_run: str | None


class DataIndex(Strict):
    profiles: list[ProfileSummary]
    runs: list[RunIndexEntry]


class VersionStatus(Strict):
    id: str
    lang: str
    compiler: str
    current: str
    latest: str | None
    status: Literal["current", "behind", "unknown"]
    error: str | None = None


class VersionReport(Strict):
    checked_at: str
    toolchains: list[VersionStatus]
