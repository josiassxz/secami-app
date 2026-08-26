import { useEffect, useRef, useState } from 'react';
import { X, Camera, RotateCcw } from 'lucide-react';

export default function WebcamCapture({ onCapture, onClose }) {
  const videoRef = useRef(null);
  const canvasRef = useRef(null);
  const streamRef = useRef(null);
  const [captured, setCaptured] = useState(null);
  const [error, setError] = useState('');

  useEffect(() => {
    navigator.mediaDevices.getUserMedia({ video: true })
      .then(stream => {
        streamRef.current = stream;
        if (videoRef.current) videoRef.current.srcObject = stream;
      })
      .catch(() => setError('Não foi possível acessar a câmera. Verifique as permissões.'));

    return () => {
      streamRef.current?.getTracks().forEach(t => t.stop());
    };
  }, []);

  const handleCapture = () => {
    const video = videoRef.current;
    const canvas = canvasRef.current;
    canvas.width = video.videoWidth;
    canvas.height = video.videoHeight;
    canvas.getContext('2d').drawImage(video, 0, 0);
    setCaptured(canvas.toDataURL('image/jpeg', 0.9));
  };

  const handleConfirm = () => {
    onCapture(captured);
    streamRef.current?.getTracks().forEach(t => t.stop());
  };

  return (
    <div className="fixed inset-0 bg-black/70 z-[60] flex items-center justify-center p-4">
      <div className="bg-card border border-border rounded-2xl w-full max-w-md overflow-hidden">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <h2 className="font-semibold text-foreground">Tirar Foto</h2>
          <button onClick={onClose}><X className="w-4 h-4 text-muted-foreground" /></button>
        </div>

        <div className="p-5 space-y-4">
          {error ? (
            <p className="text-sm text-destructive text-center py-6">{error}</p>
          ) : (
            <>
              {!captured ? (
                <video ref={videoRef} autoPlay playsInline className="w-full rounded-xl aspect-video object-cover bg-black" />
              ) : (
                <img src={captured} alt="Captura" className="w-full rounded-xl aspect-video object-cover" />
              )}
              <canvas ref={canvasRef} className="hidden" />
              <div className="flex gap-3">
                {!captured ? (
                  <button
                    onClick={handleCapture}
                    className="flex-1 flex items-center justify-center gap-2 py-2.5 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90"
                  >
                    <Camera className="w-4 h-4" /> Capturar
                  </button>
                ) : (
                  <>
                    <button
                      onClick={() => setCaptured(null)}
                      className="flex-1 flex items-center justify-center gap-2 py-2.5 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30"
                    >
                      <RotateCcw className="w-4 h-4" /> Refazer
                    </button>
                    <button
                      onClick={handleConfirm}
                      className="flex-1 py-2.5 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90"
                    >
                      Usar esta foto
                    </button>
                  </>
                )}
              </div>
            </>
          )}
        </div>
      </div>
    </div>
  );
}