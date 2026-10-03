"""Build a before/after listening page and technical checks without altering baseline results."""
import hashlib
import json
import wave
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"experiments/audio/output"
GAIN={"kick":-12,"pass":-16,"hit":-19,"save":-14,"super":-12,"goal":-9,"whistle":-20}

def read(path):
    with wave.open(str(path),"rb") as f:
        rate=f.getframerate(); data=np.frombuffer(f.readframes(f.getnframes()),dtype="<i2").astype(float)/32768
    return rate,data

def write(path,rate,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    assert np.max(np.abs(data)) < 1
    with wave.open(str(path),"wb") as f:
        f.setparams((1,2,rate,0,"NONE","not compressed"))
        f.writeframes(np.rint(data*32767).astype("<i2").tobytes())

def main():
    rows=[]
    for path in sorted((ROOT/"assets").glob("*.wav")):
        rate,x=read(path)
        peak=float(np.max(np.abs(x)))
        assert rate==48000 and peak<.73 and x[0]==0 and x[-1]==0,path
        rows.append({"name":path.name,"peak_dbfs":round(20*np.log10(peak),2),
                     "rms_dbfs":round(20*np.log10(np.sqrt(np.mean(x*x))),2),
                     "duration":round(len(x)/rate,4),"zero_endpoints":True,
                     "sha256":hashlib.sha256(path.read_bytes()).hexdigest()})
        category=path.stem.split("_")[0]
        write(OUT/"redesign"/path.name,rate,x*10**(GAIN[category]/20))
    sections=['<h1>Ballkickers: new sound</h1><p>Recorded kicks and whistle, soft varied tackles, '
              'dedicated keeper saves, and a warm goal melody.</p><p>These comparisons use the game’s '
              'actual playback gains. The new mix deliberately makes repeated tackles quieter. '
              'The old and new clips are not loudness matched.</p>']
    for name,description in [
        ("kick","Recorded football contact with a short low thump; four variations."),
        ("pass","A lighter, softer touch; three variations."),
        ("hit","Soft body contact with a small turf layer; four variations. Duplicate hits are suppressed for 120 ms."),
        ("save","A distinct padded catch; three variations."),
        ("super","A powerful ball strike with a brief air sweep; two variations."),
        ("goal","An overlapping four-note celebration with smooth note endings."),
        ("whistle","A short recorded whistle, mixed lower to keep it from dominating.")]:
        sections.append(f'<section><h2>{name.capitalize()}</h2><p>{description}</p>')
        old="hit" if name=="save" else name
        sections.append(f'<label>Before<audio controls preload="none" src="native/{old}.wav"></audio></label>')
        sections.append(f'<label>Now<audio controls preload="none" src="redesign/{name}.wav"></audio></label></section>')
    sections.append('<h2>Listen in a match</h2><video controls preload="metadata" style="width:100%;border-radius:12px" src="redesign-match.mp4"></video><p>A 20-second recording from the game with the new mix. Includes kicks, tackles, saves and a goal.</p><p>The playable build is in build/Ballkickers.exe. '
                    'Use the same speaker volume for the old and new versions.</p>'
                    '<p><a href="redesign-report.json">Technical checks</a> · <a href="index.html">Original experiment</a></p>')
    (OUT/"redesign.html").write_text('<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
        '<title>Ballkickers new audio</title><style>body{font:17px system-ui;max-width:900px;margin:40px auto;padding:0 20px;background:#101923;color:#e3edf4}'
        'p{line-height:1.55;color:#b8ccd9}section{border-top:1px solid #334656;padding:12px 0 30px}label{display:inline-block;width:48%;min-width:240px}'
        'audio{display:block;max-width:95%;margin-top:12px}a{color:#97dbff}@media(max-width:600px){label{width:100%;margin:10px 0}}</style>'
        +"".join(sections),encoding="utf-8")
    (OUT/"redesign-report.json").write_text(json.dumps({"assets":rows,"passed":True,
        "limits":"Technical checks do not establish subjective quality. No AI score used as a quality gate."},indent=2)+"\n")
    print(f"{len(rows)} sounds verified: 48 kHz, no full-scale clipping, zero endpoints; comparison page generated.")

if __name__=="__main__": main()
