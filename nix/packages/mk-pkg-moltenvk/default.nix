{
  pkgs ? import ../../utils/default/pkgs.nix,
  os ? import ../../utils/default/os.nix,
  arch ? pkgs.callPackage ../../utils/default/arch.nix { },
}:

let
  name = "moltenvk";
  pname = import ../../utils/name/package.nix name;
  callPackage = pkgs.lib.callPackageWith { inherit pkgs os arch; };
  xctoolchainLipo = callPackage ../../utils/xctoolchain/lipo.nix { };

  moltenvkPrebuiltPackageLock = (import ../../../packages.lock.nix)."moltenvk-prebuilt";
  moltenvkPrebuiltVersion = moltenvkPrebuiltPackageLock.version;

  vulkansdkLinuxPackageLock = (import ../../../packages.lock.nix)."vulkansdk-linux";
  vulkansdkLinuxVersion = vulkansdkLinuxPackageLock.version;

  version = moltenvkPrebuiltVersion;

  moltenvkPrebuiltSource = callPackage ../../utils/fetch-tarball/default.nix {
    name = import ../../utils/name/package.nix "moltenvk-prebuilt-${moltenvkPrebuiltVersion}";
    inherit (moltenvkPrebuiltPackageLock) url sha256;
  };
  vulkansdkLinuxSource = callPackage ../../utils/fetch-tarball/default.nix {
    name = import ../../utils/name/package.nix "vulkansdk-linux-${vulkansdkLinuxVersion}";
    inherit (vulkansdkLinuxPackageLock) url sha256;
  };
in

# TODO: try to build libs ourselves
pkgs.stdenvNoCC.mkDerivation {
  name = "${pname}-${os}-${arch}-${version}";
  pname = pname;
  inherit version;
  dontUnpack = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [
    xctoolchainLipo
  ];
  buildPhase = ''
    mkdir -p build/{include,lib}
    mkdir -p build/lib/pkgconfig
    mkdir -p build/share/vulkan/registry

    # copy headers from moltenvk-prebuilt
    cp -R ${moltenvkPrebuiltSource}/MoltenVK/include/* build/include/

    if [ ${arch} == "amd64" ]; then
      arch="x86_64"
    elif [ ${arch} == "arm64" ]; then
      arch="arm64"
    else
      echo "Unsupported arch ${arch}"
      exit 1
    fi

    if [ ${os} == "macos" ]; then
      os="macOS"
    elif [ ${os} == "ios" ]; then
      os="iOS"
    else
      echo "Unsupported os ${os}"
      exit 1
    fi

    if [ ${os} == "macos" ]; then
      # extract arch lib from universal lib
      lipo -extract $arch -output build/lib/libMoltenVK.dylib ${moltenvkPrebuiltSource}/MoltenVK/dylib/$os/libMoltenVK.dylib
    elif [ ${os} == "ios" ]; then
      # copy arch lib from universal lib
      cp ${moltenvkPrebuiltSource}/MoltenVK/dylib/$os/libMoltenVK.dylib build/lib/libMoltenVK.dylib
    else
      echo "Unsupported os ${os}"
      exit 1
    fi

    # copy vulkan registry from vulkansdk-linux
    cp ${vulkansdkLinuxSource}/x86_64/share/vulkan/registry/vk.xml build/share/vulkan/registry/vk.xml

    # install pkgconfig file
    cp ${./vulkan.pc.in} build/lib/pkgconfig/vulkan.pc
    sed -i "s|\''${PREFIX}|$out|g" build/lib/pkgconfig/vulkan.pc
    sed -i "s|\''${VERSION}|${version}|g" build/lib/pkgconfig/vulkan.pc
  '';
  installPhase = ''
    cp -R build $out
  '';
}
