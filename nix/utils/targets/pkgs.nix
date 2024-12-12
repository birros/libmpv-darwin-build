let
  oses = import ../constants/oses.nix;
  archs = import ../constants/archs.nix;
in
[
  {
    os = oses.ios;
    arch = archs.arm64;
  }
  # TODO: MoltenVK prebuilt libs doesn't include iossimulator
  # {
  #   os = oses.iossimulator;
  #   arch = archs.arm64;
  # }
  # {
  #   os = oses.iossimulator;
  #   arch = archs.amd64;
  # }
  {
    os = oses.macos;
    arch = archs.arm64;
  }
  {
    os = oses.macos;
    arch = archs.amd64;
  }
]
