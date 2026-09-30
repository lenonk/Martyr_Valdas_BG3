// bg3tool: small conversions for the Martyr build, via Norbyte's LSLib.
//   loca <in.xml> <out.loca>   localization XML to the game's binary .loca
//   lsf  <in.lsx> <out.lsf>    a resource to binary LSF (content banks are only read as LSF)
//   pack <dir> <out.pak>       a directory to a v18 package
using LSLib.LS;
using LSLib.LS.Enums;

// LSLib wants absolute paths.
args = args.Select((a, i) => i == 0 ? a : Path.GetFullPath(a)).ToArray();

if (args.Length == 3 && args[0] == "loca")
{
    var resource = LocaUtils.Load(args[1], LocaFormat.Xml);
    LocaUtils.Save(resource, args[2], LocaFormat.Loca);
    Console.WriteLine($"{args[2]}: {resource.Entries.Count} strings");
    return 0;
}
if (args.Length == 3 && args[0] == "lsf")
{
    var resource = ResourceUtils.LoadResource(args[1], ResourceFormat.LSX,
        ResourceLoadParameters.FromGameVersion(Game.BaldursGate3));
    ResourceUtils.SaveResource(resource, args[2], ResourceFormat.LSF,
        ResourceConversionParameters.FromGameVersion(Game.BaldursGate3));
    Console.WriteLine($"{args[2]}: LSF");
    return 0;
}
if (args.Length == 3 && args[0] == "convert")
{
    // Any resource format to any other, by extension (lsf/lsfx/lsx/lsj).
    var resource = ResourceUtils.LoadResource(args[1], ResourceUtils.ExtensionToResourceFormat(args[1]),
        ResourceLoadParameters.FromGameVersion(Game.BaldursGate3));
    ResourceUtils.SaveResource(resource, args[2], ResourceUtils.ExtensionToResourceFormat(args[2]),
        ResourceConversionParameters.FromGameVersion(Game.BaldursGate3));
    Console.WriteLine($"{args[1]} -> {args[2]}");
    return 0;
}
if (args.Length == 3 && args[0] == "pack")
{
    // A directory to a release-format (v18) package, LZ4 like divine's default.
    var build = new LSLib.LS.Pak.PackageBuildData
    {
        Version = PackageVersion.V18,
        Compression = CompressionMethod.LZ4,
    };
    await new LSLib.LS.Pak.Packager().CreatePackage(args[2], args[1], build);
    Console.WriteLine($"{args[2]}: v18 package");
    return 0;
}
Console.Error.WriteLine("usage: bg3tool loca <in.xml> <out.loca> | lsf <in.lsx> <out.lsf> | convert <in> <out> | pack <dir> <out.pak>");
return 2;
