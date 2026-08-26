import { useState } from 'react';
import { base44 } from '@/api/base44Client';
import { X, Camera, Loader2, Video } from 'lucide-react';
import WebcamCapture from './WebcamCapture';

export default function StudentProfileModal({ student, onSave, onClose }) {
  const [weight, setWeight] = useState(student?.weight || '');
  const [height, setHeight] = useState(student?.height || '');
  const [phone, setPhone] = useState(student?.phone || '');
  const [photoUrl, setPhotoUrl] = useState(student?.photo_url || '');
  const [uploading, setUploading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [showWebcam, setShowWebcam] = useState(false);

  const handlePhotoChange = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    setUploading(true);
    const { file_url } = await base44.integrations.Core.UploadFile({ file });
    setPhotoUrl(file_url);
    setUploading(false);
  };

  const handleWebcamCapture = async (dataUrl) => {
    setShowWebcam(false);
    setUploading(true);
    const blob = await (await fetch(dataUrl)).blob();
    const file = new File([blob], 'webcam.jpg', { type: 'image/jpeg' });
    const { file_url } = await base44.integrations.Core.UploadFile({ file });
    setPhotoUrl(file_url);
    setUploading(false);
  };

  const handleSave = async () => {
    setSaving(true);
    const data = {};
    if (weight) data.weight = parseFloat(weight);
    if (height) data.height = parseFloat(height);
    if (phone) data.phone = phone;
    data.photo_url = photoUrl || '';
    await base44.entities.Student.update(student.id, data);
    setSaving(false);
    onSave();
  };

  const inputCls = "w-full bg-background border border-border rounded-lg px-3 py-2 text-sm text-foreground focus:outline-none focus:ring-2 focus:ring-ring";

  return (
    <div className="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4">
      {showWebcam && <WebcamCapture onCapture={handleWebcamCapture} onClose={() => setShowWebcam(false)} />}
      {uploading && (
        <div className="fixed inset-0 bg-black/60 z-[9999] flex flex-col items-center justify-center gap-3">
          <Loader2 className="w-10 h-10 animate-spin text-primary" />
          <p className="text-sm text-white font-medium">Enviando foto, aguarde...</p>
        </div>
      )}
      <div className="bg-card border border-border rounded-2xl w-full max-w-sm">
        <div className="flex items-center justify-between px-5 py-4 border-b border-border">
          <h2 className="font-semibold text-foreground">Editar Meu Perfil</h2>
          <button onClick={onClose}><X className="w-4 h-4 text-muted-foreground" /></button>
        </div>
        <div className="p-5 space-y-4">
          {/* Foto */}
          <div className="flex flex-col items-center gap-3">
            <div className="relative w-20 h-20">
              {photoUrl ? (
                <img src={photoUrl} alt="foto" className="w-20 h-20 rounded-full object-cover border-2 border-primary" />
              ) : (
                <div className="w-20 h-20 rounded-full bg-primary/20 flex items-center justify-center text-primary text-2xl font-bold border-2 border-primary/40">
                  {student?.full_name?.[0]?.toUpperCase()}
                </div>
              )}
              <label className="absolute bottom-0 right-0 bg-primary text-primary-foreground rounded-full p-1.5 cursor-pointer hover:bg-primary/90">
                <Camera className="w-3 h-3" />
                <input type="file" accept="image/*" className="hidden" onChange={handlePhotoChange} disabled={uploading} />
              </label>
            </div>
            <p className="text-sm font-medium text-foreground">{student?.full_name}</p>
            <button
              type="button"
              onClick={() => setShowWebcam(true)}
              disabled={uploading}
              className="flex items-center gap-2 bg-background border border-border rounded-lg px-3 py-1.5 text-xs text-muted-foreground hover:border-primary/50 transition-colors disabled:opacity-50"
            >
              <Video className="w-3.5 h-3.5" /> Usar webcam
            </button>
          </div>

          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block text-xs font-medium text-muted-foreground mb-1">Peso (kg)</label>
              <input type="number" className={inputCls} value={weight} onChange={e => setWeight(e.target.value)} placeholder="Ex: 75" />
            </div>
            <div>
              <label className="block text-xs font-medium text-muted-foreground mb-1">Altura (cm)</label>
              <input type="number" className={inputCls} value={height} onChange={e => setHeight(e.target.value)} placeholder="Ex: 175" />
            </div>
          </div>

          <div>
            <label className="block text-xs font-medium text-muted-foreground mb-1">Telefone</label>
            <input type="tel" className={inputCls} value={phone} onChange={e => setPhone(e.target.value)} placeholder="(00) 00000-0000" />
          </div>

          <div className="flex gap-3 pt-1">
            <button onClick={onClose} className="flex-1 py-2 border border-border rounded-lg text-sm text-muted-foreground hover:bg-muted/30">Cancelar</button>
            <button onClick={handleSave} disabled={saving} className="flex-1 py-2 bg-primary text-primary-foreground rounded-lg text-sm font-medium hover:bg-primary/90 disabled:opacity-50">
              {saving ? 'Salvando...' : 'Salvar'}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}