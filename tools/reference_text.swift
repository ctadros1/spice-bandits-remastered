// Read local reference captures with on-device Vision. OCR is supporting
// evidence; transcriptions and visible geometry still require image review.
import Foundation
import Vision
var rows:[[String:Any]]=[]
for name in CommandLine.arguments.dropFirst() {
 let request=VNRecognizeTextRequest()
 request.recognitionLevel = .accurate
 request.recognitionLanguages=["en-US"]
 request.usesLanguageCorrection=false
 try VNImageRequestHandler(url:URL(fileURLWithPath:name),options:[:]).perform([request])
 let lines=(request.results ?? []).filter {$0.boundingBox.minX>0.60}.sorted {$0.boundingBox.maxY>$1.boundingBox.maxY}.compactMap {item->[String:Any]? in
  guard let text=item.topCandidates(1).first else {return nil}
  let b=item.boundingBox
  return ["text":text.string,"confidence":text.confidence,"rect":[b.minX,1-b.maxY,b.width,b.height]]
 }
 rows.append(["file":name,"lines":lines])
}
let data=try JSONSerialization.data(withJSONObject:rows,options:[.prettyPrinted,.sortedKeys])
FileHandle.standardOutput.write(data)
