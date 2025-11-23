import { useState, useRef } from "react";
import Meyda from "meyda";
import RecorderButton from "./components/RecorderButton";
import WaveformDisplay from "./components/WaveformDisplay";
import AudioStatusBar from "./components/AudioStatusBar";
import TranscriptPanel from "./components/TranscriptPanel";

// 简易自相关法估算基频 F0（Hz）
function estimatePitch(timeDomainData, sampleRate) {
  const len = timeDomainData.length;

  // 1️⃣ 计算整体能量，太小就是静音，直接返回 null
  let sumSquares = 0;
  for (let i = 0; i < len; i++) {
    const v = timeDomainData[i];
    if (!Number.isNaN(v)) {
      sumSquares += v * v;
    }
  }
  const rms = Math.sqrt(sumSquares / len);
  if (rms < 0.01) {
    // 声音太小，当作无声处理
    return null;
  }

  // 2️⃣ 自相关计算（简化版）
  const maxLag = Math.floor(sampleRate / 80);   // 最低 80Hz 左右
  const minLag = Math.floor(sampleRate / 400);  // 最高 400Hz 左右

  let bestLag = -1;
  let bestCorr = 0;

  for (let lag = minLag; lag <= maxLag; lag++) {
    let corr = 0;
    for (let i = 0; i < len - lag; i++) {
      corr += timeDomainData[i] * timeDomainData[i + lag];
    }
    if (corr > bestCorr) {
      bestCorr = corr;
      bestLag = lag;
    }
  }

  if (bestLag === -1 || bestCorr <= 0) {
    return null;
  }

  // 3️⃣ lag → 频率（Hz）
  const freq = sampleRate / bestLag;
  return freq;
}



function App() {
  const [isRecording, setIsRecording] = useState(false);
  const [statusText, setStatusText] = useState("idle");
  const mediaRecorderRef = useRef(null);
  const mediaStreamRef = useRef(null);
  const recordedChunksRef = useRef([]);
  const [audioUrl, setAudioUrl] = useState(null);
  const [energy, setEnergy] = useState(0); // 实时能量值（0~约0.5）
  const audioContextRef = useRef(null);
  const analyserNodeRef = useRef(null);
  const animationFrameRef = useRef(null);
  const [pitch, setPitch] = useState(null);




  const startRecording = async () => {
    try {
      setStatusText("requesting microphone permission...");
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      mediaStreamRef.current = stream;

      // 🆕 创建 AudioContext + AnalyserNode，用于实时能量分析
      const AudioContextClass =
        window.AudioContext || window.webkitAudioContext;
      const audioContext = new AudioContextClass();
      audioContextRef.current = audioContext;

      const source = audioContext.createMediaStreamSource(stream);
      const analyser = audioContext.createAnalyser();
      analyser.fftSize = 2048; // buffer size，会影响平滑度
      source.connect(analyser);
      analyserNodeRef.current = analyser;

      // 启动能量分析循环
      startEnergyAnalysis(analyser, audioContext);


      // ✅ 保留你之前的 MediaRecorder 逻辑
      const mediaRecorder = new MediaRecorder(stream);
      mediaRecorderRef.current = mediaRecorder;
      recordedChunksRef.current = [];

      mediaRecorder.ondataavailable = (event) => {
        if (event.data && event.data.size > 0) {
          recordedChunksRef.current.push(event.data);
        }
      };

      mediaRecorder.onstart = () => {
        setStatusText("recording");
      };

      mediaRecorder.onstop = () => {
        setStatusText("stopped");
        const blob = new Blob(recordedChunksRef.current, { type: "audio/webm" });
        console.log("Recorded audio blob:", blob);

        if (audioUrl) {
          URL.revokeObjectURL(audioUrl);
        }
        const url = URL.createObjectURL(blob);
        setAudioUrl(url);
      };

      mediaRecorder.start();
      setIsRecording(true);
    } catch (error) {
      console.error("Error accessing microphone:", error);
      setStatusText("error: cannot access microphone");
      setIsRecording(false);
    }
  };


  const stopRecording = () => {
    const mediaRecorder = mediaRecorderRef.current;
    const stream = mediaStreamRef.current;

    if (mediaRecorder && mediaRecorder.state !== "inactive") {
      mediaRecorder.stop();
    }

    if (stream) {
      stream.getTracks().forEach((track) => track.stop());
    }

    // 🆕 停止能量分析动画
    if (animationFrameRef.current) {
      cancelAnimationFrame(animationFrameRef.current);
      animationFrameRef.current = null;
    }

    // 🆕 关闭 AudioContext
    if (audioContextRef.current) {
      audioContextRef.current.close();
      audioContextRef.current = null;
    }

    setEnergy(0);
    setPitch(null);
    setIsRecording(false);
    

  };


  const handleToggleRecording = () => {
    if (isRecording) {
      stopRecording();
    } else {
      startRecording();
    }
  };

  const startEnergyAnalysis = (analyser, audioContext) => {
    const bufferLength = analyser.fftSize;
    const dataArray = new Float32Array(bufferLength);
  
    const analyze = () => {
      // 从 AnalyserNode 中读取当前帧的时域数据
      analyser.getFloatTimeDomainData(dataArray);
  
      // 1️⃣ 计算 RMS 能量
      let sumSquares = 0;
      for (let i = 0; i < bufferLength; i++) {
        const v = dataArray[i];
        if (!Number.isNaN(v)) {
          sumSquares += v * v;
        }
      }
      const rms = Math.sqrt(sumSquares / bufferLength);
      setEnergy(rms);
  
      // 2️⃣ 估算 Pitch（Hz）
      const pitchValue = estimatePitch(dataArray, audioContext.sampleRate);
      if (pitchValue && !Number.isNaN(pitchValue)) {
        setPitch(pitchValue);
      } else {
        setPitch(null);
      }
  
      // 3️⃣ 下一帧
      animationFrameRef.current = requestAnimationFrame(analyze);
    };
  
    analyze();
  };
  
  



  return (
    <div
      style={{
        padding: "2rem",
        maxWidth: "600px",
        margin: "0 auto",
        fontFamily:
          "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
      }}
    >
      <h1>ShadowVoice 🎤</h1>
      <p style={{ opacity: 0.8, marginBottom: "1.5rem" }}>
        Frontend skeleton is ready. Now microphone recording is wired up.
      </p>

      <RecorderButton
        isRecording={isRecording}
        onToggle={handleToggleRecording}
      />
      <WaveformDisplay energy={energy} pitch={pitch} />
      <AudioStatusBar text={statusText} />


    {audioUrl && (
      <div style={{ marginTop: "1rem" }}>
        <h3>Playback</h3>
        <audio
          controls
          src={audioUrl}
          style={{ width: "100%" }}
        />
      </div>
    )}

    <TranscriptPanel />

    </div>
  );

}

export default App;
