"""Outline SVG text for Godot's SVG renderer (which does not render text).

Requires fonttools; the resulting SVG contains geometry, not embedded fonts.
"""
import sys
from pathlib import Path
import xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'captures/asset-tools'))
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
path=root/'assets/cover.svg'
tree=ET.parse(path)
ns='http://www.w3.org/2000/svg'
ET.register_namespace('',ns)
font=TTFont('C:/Windows/Fonts/arialbd.ttf')
glyphs=font.getGlyphSet(); cmap=font.getBestCmap(); units=font['head'].unitsPerEm
for node in list(tree.getroot()):
    if node.tag != '{'+ns+'}text': continue
    size=float(node.attrib['font-size']); scale=size/units
    spacing=float(node.get('letter-spacing','0'))
    chars=node.text or ''
    width=sum(glyphs[cmap[ord(c)]].width*scale+spacing for c in chars)-spacing
    x=float(node.get('x','0')); y=float(node.get('y','0'))
    # Fit title to the panel while preserving line weight and a clean margin.
    horizontal=min(1,530/width)
    if node.get('text-anchor')=='middle': x-=width*horizontal/2
    pen=SVGPathPen(glyphs)
    for c in chars:
        glyph=glyphs[cmap[ord(c)]]
        glyph.draw(TransformPen(pen,(scale*horizontal,0,0,-scale,x,y)))
        x+=(glyph.width*scale+spacing)*horizontal
    node.tag='{'+ns+'}path'
    fill=node.get('fill'); node.attrib.clear()
    node.set('fill',fill); node.set('d',pen.getCommands()); node.text=None
tree.write(path,encoding='utf-8',xml_declaration=False)
