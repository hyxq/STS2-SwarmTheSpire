using System;
using System.Reflection;

class Inspect {
    static void Main() {
        var dll = @"D:\SteamLibrary\steamapps\common\Slay the Spire 2\mods\RitsuLib\STS2-RitsuLib.dll";
        var resolver = new ResolveEventHandler((s, e) => {
            var name = new AssemblyName(e.Name).Name;
            var path = @"D:\SteamLibrary\steamapps\common\Slay the Spire 2\data_sts2_windows_x86_64\" + name + ".dll";
            return Assembly.LoadFrom(path);
        });
        AppDomain.CurrentDomain.AssemblyResolve += resolver;
        try {
            var asm = Assembly.LoadFrom(dll);
            var type = asm.GetType("STS2RitsuLib.Keywords.ModKeywordRegistry");
            if (type == null) { Console.WriteLine("Type not found"); return; }
            foreach (var m in type.GetMethods(BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance | BindingFlags.NonPublic)) {
                if (m.Name.Contains("Register") || m.Name.Contains("Instance") || m.Name == "Get" || m.Name.Contains("Create")) {
                    var ps = string.Join(", ", Array.ConvertAll(m.GetParameters(), p => p.ParameterType.Name + " " + p.Name));
                    Console.WriteLine((m.IsStatic ? "STATIC " : "") + m.Name + "(" + ps + ") -> " + m.ReturnType.Name);
                }
            }
            // Also list properties
            foreach (var p in type.GetProperties(BindingFlags.Public | BindingFlags.Static | BindingFlags.Instance)) {
                Console.WriteLine("PROP " + (p.GetMethod?.IsStatic == true ? "STATIC " : "") + p.Name + " : " + p.PropertyType.Name);
            }
        } catch (Exception ex) { Console.WriteLine("ERROR: " + ex.Message); }
    }
}
