import PackagePlugin
import Foundation

@main
struct MetalCompilerPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        let metalFiles = target.directory.filter { $0.extension == "metal" }
        
        return try metalFiles.map { metalFile in
            let input = context.pluginWorkDirectory.appending(metalFile.lastComponent)
            let output = context.pluginWorkDirectory.appending("\(metalFile.stem).metallib")
            
            return .buildCommand(
                displayName: "Compiling Metal shader \(metalFile.lastComponent)",
                executable: try context.tool(named: "xcrun").path,
                arguments: [
                    "metal",
                    "-c",
                    metalFile.string,
                    "-o",
                    output.string
                ],
                inputFiles: [metalFile],
                outputFiles: [output]
            )
        }
    }
}
