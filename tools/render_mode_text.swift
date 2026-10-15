// Reconstruct fixed English mode-title shadow textures from the preserved font.
// CoreText replaces the unavailable old UIKit glyph draw; CoreGraphics retains
// the recovered zero-offset7px shadow and seven repeated white text draws.
import Foundation
import CoreText
import CoreGraphics
import ImageIO

let root=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
let fontURL=root.appendingPathComponent("game/assets/fonts/Kautiva Pro Bold.otf")
let output=root.appendingPathComponent("game/assets/derived/mode_text",isDirectory:true)
try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
let graphics=CGFont(CGDataProvider(url:fontURL as CFURL)!)!
let color=CGColor(gray:1,alpha:1)
let padding=7
func power2(_ value:Int)->Int {var result=1;while result<value {result*=2};return result}
var rows:[[String:Any]]=[]
var texts:[(String,CGFloat)]=["Training","Normal","Sudden Death","Air Attack","Camps","Cooperative","Competition"].map{($0,28)}
let catalog=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("game/data/catalog.json"))) as! [String:Any]
let interface=try JSONSerialization.jsonObject(with:Data(contentsOf:root.appendingPathComponent("game/data/interface_tutorials.json"))) as! [String:Any]
let players=(interface["mode_texts"] as! [String:String])["players"]!
let counts=Set((catalog["configs"] as! [[String:Any]]).compactMap{Int(String(describing:$0["numplayers"] ?? "1"))}.filter{$0>1}).sorted()
texts+=counts.map{("\($0) "+players,14)}
for (index,item) in texts.enumerated() {
 let (text,points)=item
 let font=CTFontCreateWithGraphicsFont(graphics,points,nil,nil)
 let line=CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:[NSAttributedString.Key(kCTFontAttributeName as String):font,NSAttributedString.Key(kCTForegroundColorAttributeName as String):color]))
 let contentWidth=ceil(CTLineGetTypographicBounds(line,nil,nil,nil))
 let ascent=ceil(CTFontGetAscent(font))
 let contentHeight=ceil(CTFontGetAscent(font)+CTFontGetDescent(font)+CTFontGetLeading(font))
 let width=power2(Int(contentWidth)+padding),height=power2(Int(contentHeight)+padding)
 let space=CGColorSpaceCreateDeviceRGB()
 let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue|CGBitmapInfo.byteOrder32Big.rawValue)!
 context.setAllowsAntialiasing(true);context.setShouldAntialias(true)
 context.setShadow(offset:.zero,blur:7,color:color)
 for _ in 0..<7 {
  context.textPosition=CGPoint(x:CGFloat(padding),y:CGFloat(height-padding)-ascent)
  CTLineDraw(line,context)
 }
 let filename="\(index).png"
 let destination=CGImageDestinationCreateWithURL(output.appendingPathComponent(filename) as CFURL,"public.png" as CFString,1,nil)!
 CGImageDestinationAddImage(destination,context.makeImage()!,nil)
 guard CGImageDestinationFinalize(destination) else {fatalError("PNG write failed")}
 rows.append(["text":text,"font_size":points,"path":"assets/derived/mode_text/"+filename,"size":[width,height],"content":[contentWidth,contentHeight],"baseline":ascent,"padding":padding])
}
let record:[String:Any]=["method":"Recovered CLevelItem28pt bold titles and14pt static player-count underlays; blurShadow(true,7,7,white,white). Current macOS CoreText/CoreGraphics replace old UIKit glyph raster at explicit content scale1; original device raster and GL compositing remain unproven.","font_size":28,"player_count_font_size":14,"shadow_blur":7,"shadow_intensity":7,"content_scale":1,"renderer":ProcessInfo.processInfo.operatingSystemVersionString,"entries":rows]
let data=try JSONSerialization.data(withJSONObject:record,options:[.prettyPrinted,.sortedKeys])
try data.write(to:root.appendingPathComponent("game/data/mode_text.json"))
print("MODE_TEXT_DERIVATION \(rows.count) preserved-font title textures")
