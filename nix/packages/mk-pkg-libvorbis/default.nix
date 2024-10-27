{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "libvorbis";
  version = "1.3.7";
  url = "https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz";
  # archiveSha256 = "0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab";
  sha256 = "0bcvamndfzxsmna9cx9y1malvj86hghffbilxrbn51mlqbr74yy5";

  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  nativeFile = callPackage ../../utils/native-file/default.nix { };
  crossFile = callPackage ../../utils/cross-file/default.nix { };
  libogg = callPackage ../mk-pkg-libogg/default.nix { };

  pname = import ../../utils/name/package.nix name;
  src = builtins.fetchTarball {
    name = "${pname}-source-${version}";
    inherit url;
    inherit sha256;
  };
  patchedSource = pkgs.runCommand "${pname}-patched-source-${version}" { } ''
    cp -r ${src} src
    export src=$PWD/src
    chmod -R 777 $src

    cd $src
    patch -p1 <${../../../patches/ltmain-target-passthrough.patch}
    cd -

    # Fix building on modern macOS
    sed -i 's/\-force_cpusubtype_ALL//g' $src/configure

    cp ${./meson.build} $src/meson.build

    cp -r $src $out
  '';
in

pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  src = patchedSource;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    pkgs.meson
    pkgs.ninja
    pkgs.pkg-config
  ];
  buildInputs = [
    libogg
  ];
  configurePhase = ''
    meson setup build $src \
      --native-file ${nativeFile} \
      --cross-file ${crossFile} \
      --prefix=$out
  '';
  buildPhase = ''
    meson compile -vC build $(basename $src)
  '';
  installPhase = ''
    meson install -C build

    # BUG: Force linking to libogg in pkg-config file to fix ffmpeg configure
    # step which try linking to it without specifing flags
    sed -i "s|-lvorbis|-lvorbis $(pkg-config --libs ogg)|g" $out/lib/pkgconfig/vorbis.pc
    sed -i "s|{includedir}|{includedir} $(pkg-config --cflags ogg)|g" $out/lib/pkgconfig/vorbis.pc
  '';
}
