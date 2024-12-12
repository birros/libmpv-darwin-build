{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "glslang";
  packageLock = (import ../../../packages.lock.nix).${name};
  inherit (packageLock) version;

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };

  nativeBuildInputs = [
    pkgs.cmake
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
    pkgs.python3
  ];

  pname = import ../../utils/name/package.nix name;
  src = callPackage ../../utils/fetch-tarball/default.nix {
    name = "${pname}-source-${version}";
    inherit (packageLock) url sha256;
  };
  patchedSource = pkgs.runCommand "${pname}-patched-source-${version}" { } ''
    mkdir -p $out/subprojects/glslang
    cp -r ${src}/* $out/subprojects/glslang/
    cp ${./meson.build} $out/meson.build
  '';
  fixedSource = callPackage ../../utils/patch-shebangs/default.nix {
    name = "${pname}-fixed-source-${version}";
    src = patchedSource;
    inherit nativeBuildInputs;
  };
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  src = fixedSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  inherit nativeBuildInputs;
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out
  '';
  buildPhase = ''
    meson compile -vC build
  '';
  installPhase = ''
    meson install -C build

    # install pkgconfig file
    mkdir -p $out/lib/pkgconfig
    cp ${./glslang.pc.in} $out/lib/pkgconfig/glslang.pc
    sed -i "s|\''${PREFIX}|$out|g" $out/lib/pkgconfig/glslang.pc
    sed -i "s|\''${VERSION}|${version}|g" $out/lib/pkgconfig/glslang.pc
  '';
}
