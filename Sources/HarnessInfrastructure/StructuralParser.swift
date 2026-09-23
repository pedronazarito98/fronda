import CTreeSitter
import Foundation

/// Real syntax trees; unsupported languages retain lexical search without fabricated edges.
enum StructuralParser {
    struct Structure {
        var symbols = [String]()
        var imports = [String]()
        var references = [String]()
        var hasErrors = false
        var supported = false
    }
    static func parse(_ text: String, extension ext: String) -> Structure {
        var result = Structure()
        let language: OpaquePointer?
        switch ext.lowercased() {
        case "ts": language = tree_sitter_typescript()
        case "tsx": language = tree_sitter_tsx()
        case "js", "jsx", "mjs", "cjs": language = tree_sitter_javascript()
        case "swift": language = tree_sitter_swift()
        case "py": language = tree_sitter_python()
        case "go": language = tree_sitter_go()
        default: return result
        }
        guard let parser = ts_parser_new() else { return result }
        defer { ts_parser_delete(parser) }
        guard ts_parser_set_language(parser, language) else { return result }
        let bytes = Array(text.utf8)
        let tree = text.withCString { ts_parser_parse_string(parser, nil, $0, UInt32(bytes.count)) }
        guard let tree else { return result }
        defer { ts_tree_delete(tree) }
        result.supported = true
        let root = ts_tree_root_node(tree)
        result.hasErrors = ts_node_has_error(root)
        let definitions: Set<String> = [
            "function_declaration", "function_definition", "method_declaration", "method_definition",
            "class_declaration", "class_definition", "interface_declaration", "type_alias_declaration", "type_spec",
            "struct_declaration", "enum_declaration", "protocol_declaration", "actor_declaration",
            "variable_declarator", "property_declaration", "typealias_declaration",
        ]
        let importTypes: Set<String> = [
            "import_statement", "import_declaration", "import_from_statement", "import_spec",
        ]
        var stack = [root]
        var visited = 0
        func source(_ node: TSNode) -> String {
            let start = Int(ts_node_start_byte(node))
            let end = Int(ts_node_end_byte(node))
            guard start <= end, end <= bytes.count else { return "" }
            return String(decoding: bytes[start..<end], as: UTF8.self)
        }
        while let node = stack.popLast(), visited < 100_000 {
            visited += 1
            let type = String(cString: ts_node_type(node))
            if definitions.contains(type) {
                var name = "name".withCString { ts_node_child_by_field_name(node, $0, 4) }
                if ts_node_is_null(name) {
                    for offset in 0..<ts_node_named_child_count(node) {
                        let child = ts_node_named_child(node, offset)
                        let childType = String(cString: ts_node_type(child))
                        if ["simple_identifier", "identifier", "type_identifier"].contains(childType) {
                            name = child
                            break
                        }
                    }
                }
                if !ts_node_is_null(name) {
                    result.symbols.append("\(source(name)) · L\(ts_node_start_point(node).row + 1)")
                }
            }
            if importTypes.contains(type) { result.imports.append(String(source(node).prefix(300))) }
            if ["call_expression", "call"].contains(type) {
                var function = "function".withCString { ts_node_child_by_field_name(node, $0, 8) }
                if ts_node_is_null(function), ts_node_named_child_count(node) > 0 {
                    function = ts_node_named_child(node, 0)
                }
                if !ts_node_is_null(function) {
                    result.references.append("\(source(function).prefix(120)) · L\(ts_node_start_point(node).row + 1)")
                }
            }
            for offset in (0..<ts_node_named_child_count(node)).reversed() {
                stack.append(ts_node_named_child(node, offset))
            }
        }
        result.symbols = Array(result.symbols.prefix(500))
        result.imports = Array(result.imports.prefix(200))
        result.references = Array(result.references.prefix(300))
        return result
    }
}
