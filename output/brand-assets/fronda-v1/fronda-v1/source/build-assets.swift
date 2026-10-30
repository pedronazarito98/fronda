import AppKit
import CoreText

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "output/brand-assets/fronda-v1", isDirectory: true)
let fm = FileManager.default
struct Shape {
    var path = CGMutablePath()
    var data = ""
    mutating func m(_ x: CGFloat, _ y: CGFloat) { path.move(to: CGPoint(x:x,y:y)); data += "M\(x) \(y) " }
    mutating func l(_ x: CGFloat, _ y: CGFloat) { path.addLine(to: CGPoint(x:x,y:y)); data += "L\(x) \(y) " }
    mutating func c(_ a:CGFloat,_ b:CGFloat,_ c:CGFloat,_ d:CGFloat,_ e:CGFloat,_ f:CGFloat) { path.addCurve(to:CGPoint(x:e,y:f),control1:CGPoint(x:a,y:b),control2:CGPoint(x:c,y:d)); data += "C\(a) \(b) \(c) \(d) \(e) \(f) " }
    mutating func z() { path.closeSubpath(); data += "Z " }
}
func stem() -> Shape {
    var s = Shape(); s.m(34,354); s.c(64,329,73,282,78,239); s.l(92,131); s.c(97,75,125,32,165,21); s.c(196,13,221,25,228,48); s.c(202,33,176,48,162,74); s.c(139,114,132,174,126,226); s.c(119,290,106,340,78,366); s.c(61,381,26,378,22,365); s.c(20,360,26,358,34,354); s.z(); return s
}
func crown(_ micro:Bool = false) -> Shape {
    var s = Shape(); s.m(111,162); s.c(113,105,137,27,184,22); s.c(218,17,238,39,239,67); s.l(239,103)
    if micro { s.c(239,124,214,125,211,105); s.l(209,88); s.c(209,80,201,81,196,87) }
    else { s.c(239,117,223,119,221,105); s.l(220,85); s.c(220,78,212,78,211,85); s.l(211,119); s.c(211,133,194,135,193,120); s.l(193,87); s.c(193,82,187,83,183,86) }
    s.c(162,101,147,128,134,160); s.c(128,175,109,179,111,162); s.z(); return s
}
func branch(_ micro:Bool = false) -> Shape {
    var s = Shape(); s.m(116,239); s.c(115,218,128,183,150,171); s.c(185,147,224,161,229,190); s.l(230,217)
    if micro { s.c(230,237,206,240,204,221); s.l(202,208); s.c(201,203,194,205,190,212) }
    else { s.c(230,230,215,233,213,220); s.l(212,208); s.c(211,200,205,202,205,207); s.l(205,234); s.c(205,248,189,250,188,235); s.l(187,211); s.c(182,210,180,215,178,219) }
    s.c(157,232,143,241,130,249); s.c(121,253,115,249,116,239); s.z(); return s
}
func color(_ hex:String) -> CGColor { let n=UInt32(hex.dropFirst(),radix:16)!; return CGColor(colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!,components:[CGFloat((n>>16)&255)/255,CGFloat((n>>8)&255)/255,CGFloat(n&255)/255,1])! }
let palette = ["ivory":"#EEE8DA","moss":"#526048","sage":"#8D9877","clay":"#BD9674","bark":"#282620","stone":"#AEA184"]
struct Part { let shape:Shape; let fill:String }
func mark(_ appearance:String,_ micro:Bool=false) -> [Part] {
    let dark = appearance == "dark"
    return [Part(shape:stem(),fill:dark ? "#BD9674" : "#526048"),Part(shape:crown(micro),fill:dark ? "#EEE8DA" : "#AEA184"),Part(shape:branch(micro),fill:dark ? "#EEE8DA" : "#BD9674")]
}
func serialize(_ p:CGPath) -> Shape {
    var s=Shape()
    p.applyWithBlock { ptr in let e=ptr.pointee; let p=e.points
        switch e.type {
        case .moveToPoint: s.m(p[0].x,p[0].y)
        case .addLineToPoint: s.l(p[0].x,p[0].y)
        case .addQuadCurveToPoint:
            let current=s.path.currentPoint
            s.c(current.x+(p[0].x-current.x)*2/3,current.y+(p[0].y-current.y)*2/3,p[1].x+(p[0].x-p[1].x)*2/3,p[1].y+(p[0].y-p[1].y)*2/3,p[1].x,p[1].y)
        case .addCurveToPoint: s.c(p[0].x,p[0].y,p[1].x,p[1].y,p[2].x,p[2].y)
        case .closeSubpath: s.z()
        @unknown default: break
        }
    }; return s
}
let fontURL=root.appendingPathComponent("source/DMSerifDisplay-Regular.ttf")
CTFontManagerRegisterFontsForURL(fontURL as CFURL,.process,nil)
let descriptors=CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as! [CTFontDescriptor]
let font=CTFontCreateWithFontDescriptor(descriptors[0],350,nil)
let line=CTLineCreateWithAttributedString(NSAttributedString(string:"ronda",attributes:[NSAttributedString.Key(kCTFontAttributeName as String):font]))
let runs=CTLineGetGlyphRuns(line) as! [CTRun]
var letters=[Shape]()
for run in runs {
    let count=CTRunGetGlyphCount(run)
    var glyphs=[CGGlyph](repeating:0,count:count); var positions=[CGPoint](repeating:.zero,count:count)
    CTRunGetGlyphs(run,CFRangeMake(0,0),&glyphs); CTRunGetPositions(run,CFRangeMake(0,0),&positions)
    for i in 0..<count { if let p=CTFontCreatePathForGlyph(font,glyphs[i],nil) {
        var t=CGAffineTransform(a:1,b:0,c:0,d:-1,tx:244+positions[i].x,ty:368)
        letters.append(serialize(p.copy(using:&t)!))
    }}
}
let wordWidth=ceil(244+CTLineGetTypographicBounds(line,nil,nil,nil)+12)
func svg(_ parts:[Part],width:CGFloat,height:CGFloat,title:String) -> String {
    "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(width) \(height)\" role=\"img\" aria-label=\"\(title)\"><title>\(title)</title>"+parts.map{"<path fill=\"\($0.fill)\" d=\"\($0.shape.data)\"/>"}.joined()+"</svg>"
}
func write(_ name:String,_ text:String) throws { try text.write(to:root.appendingPathComponent(name),atomically:true,encoding:.utf8) }
func render(_ name:String,_ parts:[Part],view:CGSize,pixels:CGSize,background:String?=nil) throws {
    let w=Int(pixels.width),h=Int(pixels.height)
    let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x:0,y:CGFloat(h));ctx.scaleBy(x:CGFloat(w)/view.width,y:-CGFloat(h)/view.height)
    if let b=background {ctx.setFillColor(color(b));ctx.fill(CGRect(origin:.zero,size:view))}
    for part in parts {ctx.addPath(part.shape.path);ctx.setFillColor(color(part.fill));ctx.fillPath()}
    let bitmap=NSBitmapImageRep(cgImage:ctx.makeImage()!)
    try bitmap.representation(using:.png,properties:[:])!.write(to:root.appendingPathComponent(name))
}
func transformed(_ parts:[Part],_ t:CGAffineTransform) -> [Part] { parts.map { part in var t=t; return Part(shape:serialize(part.shape.path.copy(using:&t)!),fill:part.fill) } }
func icon(_ size:Int,_ micro:Bool=false) -> [Part] {
    let r=CGPath(roundedRect:CGRect(x:64,y:64,width:896,height:896),cornerWidth:204,cornerHeight:204,transform:nil)
    // Outer inset preserves a transparent margin for the macOS Dock.
    let base=Part(shape:serialize(r),fill:"#526048")
    let markParts=transformed(mark("dark",micro),CGAffineTransform(a:1.88,b:0,c:0,d:1.88,tx:265,ty:142))
    return [base]+markParts
}
for appearance in ["light","dark"] {
    let symbol=mark(appearance)
    try write("svg/fronda-symbol-\(appearance).svg",svg(symbol,width:256,height:400,title:"Fronda — símbolo \(appearance)"))
    let word=symbol+letters.map{Part(shape:$0,fill:appearance == "dark" ? "#EEE8DA" : "#526048")}
    try write("svg/fronda-wordmark-\(appearance).svg",svg(word,width:wordWidth,height:400,title:"Fronda"))
    try render("png/fronda-wordmark-\(appearance)@2x.png",word,view:CGSize(width:wordWidth,height:400),pixels:CGSize(width:wordWidth*2,height:800))
    for size in [16,24,32,48,64,128,256,512,1024] {
        // Below 32 px use one broad pendant terminal, wider negative spaces.
        let micro=size<=24
        try render("png/fronda-symbol-\(appearance)-\(size).png",mark(appearance,micro),view:CGSize(width:256,height:400),pixels:CGSize(width:ceil(CGFloat(size)*0.64),height:CGFloat(size)))
    }
    try write("svg/fronda-symbol-micro-\(appearance).svg",svg(mark(appearance,true),width:256,height:400,title:"Fronda — símbolo óptico para 16–24 px"))
}
try write("svg/fronda-app-icon.svg",svg(icon(1024),width:1024,height:1024,title:"Fronda — ícone macOS"))
try write("svg/fronda-app-icon-micro.svg",svg(icon(16,true),width:1024,height:1024,title:"Fronda — ícone macOS pequeno"))
let iconset=root.appendingPathComponent("macos/Fronda.iconset",isDirectory:true)
try fm.createDirectory(at:iconset,withIntermediateDirectories:true)
for base in [16,32,128,256,512] {
    for scale in [1,2] {
        let actual=base*scale
        try render("macos/Fronda.iconset/icon_\(base)x\(base)\(scale==2 ? "@2x" : "").png",icon(actual,base==16),view:CGSize(width:1024,height:1024),pixels:CGSize(width:actual,height:actual))
    }
}
for size in [16,24,32,48,64,128,256,512,1024] { try render("png/fronda-app-icon-\(size).png",icon(size,size<=24),view:CGSize(width:1024,height:1024),pixels:CGSize(width:size,height:size)) }
try write("palette.json",String(data:try JSONSerialization.data(withJSONObject:palette,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
print("Exported SVG paths, transparent PNGs, optical micro variants and macOS iconset. Wordmark viewBox width: \(wordWidth)")
let pdfDir=root.appendingPathComponent("pdf",isDirectory:true)
try fm.createDirectory(at:pdfDir,withIntermediateDirectories:true)
for appearance in ["light","dark"] {
    var box=CGRect(x:0,y:0,width:wordWidth,height:400)
    let url=pdfDir.appendingPathComponent("fronda-wordmark-\(appearance).pdf")
    let context=CGContext(url as CFURL,mediaBox:&box,nil)!
    context.beginPDFPage(nil); context.translateBy(x:0,y:400); context.scaleBy(x:1,y:-1)
    let parts=mark(appearance)+letters.map{Part(shape:$0,fill:appearance == "dark" ? "#EEE8DA" : "#526048")}
    for part in parts { context.addPath(part.shape.path); context.setFillColor(color(part.fill)); context.fillPath() }
    context.endPDFPage();context.closePDF()
}
let catalog=root.appendingPathComponent("macos/AppIcon.appiconset",isDirectory:true)
try fm.createDirectory(at:catalog,withIntermediateDirectories:true)
var catalogImages=[[String:String]]()
for base in [16,32,128,256,512] {
    for scale in [1,2] {
        let name="icon_\(base)x\(base)\(scale==2 ? "@2x" : "").png"
        let dest=catalog.appendingPathComponent(name)
        if fm.fileExists(atPath:dest.path) {try fm.removeItem(at:dest)}
        try fm.copyItem(at:iconset.appendingPathComponent(name),to:dest)
        catalogImages.append(["filename":name,"idiom":"mac","scale":"\(scale)x","size":"\(base)x\(base)"])
    }
}
let contents:[String:Any] = ["images":catalogImages,"info":["author":"Fronda","version":1]]
try JSONSerialization.data(withJSONObject:contents,options:[.prettyPrinted,.sortedKeys]).write(to:catalog.appendingPathComponent("Contents.json"))
