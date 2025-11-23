export default function RecorderButton({ isRecording, onToggle }) {
    return (
      <button
        onClick={onToggle}
        style={{
          padding: "1rem",
          fontSize: "1rem",
          borderRadius: "999px",
          minWidth: "180px",
          border: "none",
          cursor: "pointer",
          backgroundColor: isRecording ? "#ff4d4f" : "#4caf50",
          color: "#ffffff",
        }}
      >
        {isRecording ? "⏹ Stop Recording" : "🎤 Start Recording"}
      </button>
    );
  }
  