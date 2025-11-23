// src/components/WaveformDisplay.jsx

export default function WaveformDisplay({ energy, pitch }) {
    // 把能量值（一般在 0 ~ 0.5 左右）映射到 0~100% 做进度条
    const percentage = Math.min(100, Math.max(0, Math.round(energy * 500)));
  
    return (
      <div
        style={{
          width: "100%",
          height: "120px",
          background: "#f5f5f5",
          borderRadius: "8px",
          marginTop: "1rem",
          padding: "1rem",
          boxSizing: "border-box",
          display: "flex",
          flexDirection: "column",
          justifyContent: "space-between",
        }}
      >
        <div style={{ fontSize: "0.9rem", opacity: 0.8 }}>Energy & Pitch</div>
  
        {/* 能量条 */}
        <div
          style={{
            width: "100%",
            height: "16px",
            background: "#e0e0e0",
            borderRadius: "999px",
            overflow: "hidden",
          }}
        >
          <div
            style={{
              width: `${percentage}%`,
              height: "100%",
              borderRadius: "999px",
              background:
                "linear-gradient(90deg, #4caf50, #ff9800, #f44336)",
              transition: "width 80ms linear",
            }}
          />
        </div>
  
        {/* 数字信息：能量 + Pitch */}
        <div style={{ fontSize: "0.8rem", opacity: 0.7, marginTop: "0.25rem" }}>
          Energy: {energy.toFixed(4)}
        </div>
        <div style={{ fontSize: "0.8rem", opacity: 0.7 }}>
          Pitch: {pitch ? `${pitch.toFixed(1)} Hz` : "—"}
        </div>
      </div>
    );
  }
  