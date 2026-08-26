import { Navigate, Route, Routes } from "react-router-dom";
import { useAuth } from "@/lib/auth";
import { Spinner } from "@/components/ui";
import Layout from "@/components/Layout";
import Login from "@/pages/Login";
import Dashboard from "@/pages/Dashboard";
import Students from "@/pages/Students";
import Schedule from "@/pages/Schedule";
import CheckIn from "@/pages/CheckIn";
import Exercises from "@/pages/Exercises";
import WorkoutPlans from "@/pages/WorkoutPlans";
import Coaching from "@/pages/Coaching";
import SlotConfig from "@/pages/SlotConfig";
import BlockedDates from "@/pages/BlockedDates";
import Departments from "@/pages/Departments";
import Notices from "@/pages/Notices";
import Reports from "@/pages/Reports";

export default function App() {
  const { user, loading } = useAuth();

  if (loading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Spinner />
      </div>
    );
  }

  return (
    <Routes>
      <Route path="/login" element={user ? <Navigate to="/" replace /> : <Login />} />
      {user ? (
        <Route element={<Layout />}>
          <Route path="/" element={<Dashboard />} />
          <Route path="/alunos" element={<Students />} />
          <Route path="/agenda" element={<Schedule />} />
          <Route path="/checkin" element={<CheckIn />} />
          <Route path="/exercicios" element={<Exercises />} />
          <Route path="/fichas" element={<WorkoutPlans />} />
          <Route path="/coaching" element={<Coaching />} />
          <Route path="/horarios" element={<SlotConfig />} />
          <Route path="/datas-bloqueadas" element={<BlockedDates />} />
          <Route path="/secretarias" element={<Departments />} />
          <Route path="/avisos" element={<Notices />} />
          <Route path="/relatorios" element={<Reports />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Route>
      ) : (
        <Route path="*" element={<Navigate to="/login" replace />} />
      )}
    </Routes>
  );
}
