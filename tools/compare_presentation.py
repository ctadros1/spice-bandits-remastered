"""Build an aspect-preserving review of current package and iPad footage.

The reference is an earlier, apparently stretched recording. Captures keep
their own proportions. No image is warped and no pixel-equivalence score is
implied by paired states with different input/progression/timing.
"""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import hashlib,html,json

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'builds'
OUT=BUILD/'presentation-comparison'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    OUT.mkdir(exist_ok=True)
    package=BUILD/'Spice Bandits Remastered.app/Contents/Resources/Spice Bandits Remastered.pck'
    package_sha=sha(package)
    for suite in ['presentation','tutorial','menus','performance','audio']:
        audit=json.loads((BUILD/(suite+'-package-audit.json')).read_text())
        assert audit['passed'] and audit['pck_sha256']==package_sha,(suite,'stale or failed audit')
    rows=[]
    tutorial_times=[121,129,132,140,163,181,186,190,196,201,207,209,212,220,231,240,252,266]
    for page,second in enumerate(tutorial_times):rows.append((f'Tutorial page {page}',second,'tutorial-gallery',f'page-{page:02d}','Portrait wrapping, callout anchors, pointers and native asset proportions.'))
    rows.extend([
        ('Moving tower preview',146,'presentation-gallery','drag-preview-045','Same tower family, different requested hex/facing; compare original nearby hex shading, crosses, fading outlines and range oval.'),
        ('After first tower placement',148,'presentation-gallery','drag-placed','Different tower cell/facing and number of placements; both states hide the build arrow after the first placement.'),
        ('Tutorial victory',281,'tutorial-gallery','victory','Actual reconstructed battle, different actions/rewards; compare composition.'),
        ('Arrival porthole',111,'presentation-gallery','loading-100','Different download duration and animation age.'),
        ('Return Earth and rocket',289,'presentation-gallery','departure-100','Different animation age; compare art, movement and effects.'),
        ('Training option',105,'presentation-gallery','tutorial-modes','Single mode, glow, camera and original world chrome.'),
        ('Desert mode fan',308,'presentation-gallery','desert-modes','Fan, icons, masks, locks and original world chrome.'),
        ('Desert story',311,'presentation-gallery','desert-story','Unstretched story art and original strips/text; glows remain open.'),
        ('Reward growth',281,'presentation-gallery','result-400','Forced XP fixture, no earned rewards; compare bar geometry/reveal.'),
        ('Spice reveal',285,'presentation-gallery','result-spice-555','Forced result amount, different animation age; short burst and preserved sound are separately checked.'),
        ('Electricity',236,'presentation-gallery','active-defense','Synthetic single ribbon versus actual combat; no equivalent input/RNG.'),
        ('Tech Shop',649,'menu-gallery','shop-fresh','Different progression and selection; compare original panel/grid.'),
        ('Shop selection',657,'menu-gallery','shop-selected-owned','Synthetic stock/unlocks; compare selection and description.'),
        ('Promotion',637,'menu-gallery','level-up','Isolated earned10XP notice, recovered shared700ms fade and observed first badge. Different stock/progression; later service item/rank payloads and old text raster remain open.'),
        ('Observed level2 XP footer',671,'menu-gallery','world-observed-level2','Unsaved reference-only31/55XP,8sp,3-point pose; different unlocks/camera. This is not earned campaign play or whole-world equivalence.'),
        ('First promotion Career',692,'menu-gallery','career-first-promotion','Observed2nd Lieutenant name/gold badge, different avatar/progression; later service rank thresholds remain open.'),
        ('Fitting body',700,'menu-gallery','fitting-body','Different selected costume; compare panel and body tab.'),
        ('Fitting hats',710,'menu-gallery','fitting-hats','Different selected costume; compare panel and hats tab.'),
        ('Fitting preview',717,'menu-gallery','fitting-preview','Different selected costume; preview/cart fixture.'),
        ('Upgrades Yard',730,'menu-gallery','upgrades-grid','Synthetic profile level3 versus the recorded level2; compare original grid and chrome. Recovered1.14 font sizes retain a long-label truncation difference from this earlier recording.'),
        ('Spice Shop offline',741,'menu-gallery','spicery-offline','Original1.14 anonymous warning versus the earlier online recording; localized prices/services are unavailable.'),
        ('Spice Shop catalog pose',741,'menu-gallery','spicery-catalog','QA-only original catalog art; no StoreKit prices. Earlier free-stuff arrangement and portrait wrapping differ.'),
        ('Spice tab motion',734.583333,'menu-gallery','tab-forward-010','100ms content slide versus an observed earlier-version frame; fixed tabs/footer, different progression and catalog state. Default UIKit compositor/easing remains open.','clip-2/spice-transition/00018.jpg')
    ])
    font=ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',17)
    entries=[];sheets=[]
    for offset in range(0,len(rows),4):
        sheet=Image.new('RGB',(1040,1408),'#16191f');draw=ImageDraw.Draw(sheet)
        for index,row in enumerate(rows[offset:offset+4]):
            name,second,gallery,capture,limit=row[:5]
            reference=BUILD/'reference/dense'/row[5] if len(row)==6 else BUILD/'reference/dense/clip-2'/f'{second:05d}.jpg'
            reference_time=second if len(row)==6 else second-0.5
            current=BUILD/gallery/(capture+'.png')
            assert reference.exists() and current.exists()
            y=index*352
            draw.text((12,y+8),name,fill='white',font=font)
            draw.text((12,y+31),f'iPad guide at {reference_time:.3f}s',fill='#adb7c6',font=font)
            draw.text((532,y+31),'Current package - original4:3 canvas',fill='#adb7c6',font=font)
            for column,path in enumerate([reference,current]):
                picture=Image.open(path).convert('RGB');picture.thumbnail((504,294),Image.Resampling.LANCZOS)
                x=12+column*520+(504-picture.width)//2
                sheet.paste(picture,(x,y+55+(294-picture.height)//2))
            entries.append({'name':name,'reference':str(reference.relative_to(ROOT)),'reference_time':reference_time,'reference_sha256':sha(reference),'current':str(current.relative_to(ROOT)),'current_sha256':sha(current),'limit':limit})
        filename=f'comparison-{offset//4+1:02d}.png';sheet.save(OUT/filename);sheets.append(filename)
    source=json.loads((BUILD/'reference/dense/manifest.json').read_text())
    manifest={'pck_sha256':package_sha,'method':__doc__,'reference_manifest_sha256':sha(BUILD/'reference/dense/manifest.json'),'pairs':entries,'sheets':sheets,'complete_fidelity':False}
    (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    cards=[]
    for row in entries:
        ref=Path('..')/Path(row['reference']).relative_to('builds')
        current=Path('..')/Path(row['current']).relative_to('builds')
        cards.append(f'<section><h2>{html.escape(row["name"])}</h2><p>{html.escape(row["limit"])}</p><div class="pair"><figure><figcaption>iPad guide - {row["reference_time"]:.1f}s</figcaption><a href="{html.escape(str(ref))}"><img src="{html.escape(str(ref))}"></a></figure><figure><figcaption>Current package</figcaption><a href="{html.escape(str(current))}"><img src="{html.escape(str(current))}"></a></figure></div></section>')
    page='''<!doctype html><html><meta charset="utf-8"><title>Spice Bandits presentation comparison</title><style>body{font:16px system-ui;background:#16191f;color:#e8edf4;margin:32px}h1{font-size:28px}h2{font-size:21px}p{color:#bdc8d8;max-width:1000px;line-height:1.5}.pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}figure{margin:0}img{width:100%;height:430px;object-fit:contain;background:black}section{margin:36px 0}figcaption{margin:8px 0}@media(max-width:900px){.pair{grid-template-columns:1fr}img{height:auto}}</style><h1>Original guide and current package</h1><p>The iPad recording guides composition and interaction. Each image keeps its own proportions: the recorded stretch is not copied into the app. States differ in timing, actions and progression. This review does not establish pixel equivalence or offline completion.</p>'''
    page+=f'<p>Package: <code>{package_sha}</code>. {len(entries)} paired states. Five package suites pass; their scopes remain separate from visual acceptance.</p>'+''.join(cards)+'</html>'
    (OUT/'comparison.html').write_text(page)
    print(json.dumps({'pairs':len(entries),'sheets':len(sheets),'pck_sha256':package_sha,'complete_fidelity':False}))

if __name__=='__main__':main()
