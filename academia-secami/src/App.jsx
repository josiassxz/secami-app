import { Toaster } from "@/components/ui/toaster"
import { QueryClientProvider } from '@tanstack/react-query'
import { queryClientInstance } from '@/lib/query-client'
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import PageNotFound from './lib/PageNotFound';
import { AuthProvider, useAuth } from '@/lib/AuthContext';
import UserNotRegisteredError from '@/components/UserNotRegisteredError';
import Layout from './components/Layout';
import Dashboard from './pages/Dashboard';
import Students from './pages/Students';
import Schedule from './pages/Schedule';
import SlotConfig from './pages/SlotConfig';
import CheckIn from './pages/CheckIn.jsx';
import Exercises from './pages/Exercises';
import WorkoutPlans from './pages/WorkoutPlans';
import MyWorkout from './pages/MyWorkout';
import MySchedule from './pages/MySchedule';
import MyHistory from './pages/MyHistory';
import Reports from './pages/Reports';
import StudentLogin from './pages/StudentLogin';
import MyProfile from './pages/MyProfile';
import Notices from './pages/Notices';
import BlockedDates from './pages/BlockedDates';
import Departments from './pages/Departments';

const AuthenticatedApp = () => {
  const { isLoadingAuth, isLoadingPublicSettings, authError, navigateToLogin } = useAuth();

  if (isLoadingPublicSettings || isLoadingAuth) {
    return (
      <div className="fixed inset-0 flex items-center justify-center bg-background">
        <div className="w-8 h-8 border-4 border-muted border-t-primary rounded-full animate-spin"></div>
      </div>
    );
  }

  if (authError) {
    if (authError.type === 'user_not_registered') {
      return <UserNotRegisteredError />;
    } else if (authError.type === 'auth_required') {
      navigateToLogin();
      return null;
    }
  }

  return (
    <Routes>
      <Route path="/student-login" element={<StudentLogin />} />
      <Route element={<Layout />}>
        <Route path="/" element={<Dashboard />} />
        <Route path="/students" element={<Students />} />
        <Route path="/schedule" element={<Schedule />} />
        <Route path="/slot-config" element={<SlotConfig />} />
        <Route path="/checkin" element={<CheckIn />} />
        <Route path="/exercises" element={<Exercises />} />
        <Route path="/workout-plans" element={<WorkoutPlans />} />
        <Route path="/my-workout" element={<MyWorkout />} />
        <Route path="/my-schedule" element={<MySchedule />} />
        <Route path="/my-history" element={<MyHistory />} />
        <Route path="/reports" element={<Reports />} />
        <Route path="/my-profile" element={<MyProfile />} />
        <Route path="/notices" element={<Notices />} />
        <Route path="/blocked-dates" element={<BlockedDates />} />
        <Route path="/departments" element={<Departments />} />
      </Route>
      <Route path="*" element={<PageNotFound />} />
    </Routes>
  );
};

function App() {
  return (
    <AuthProvider>
      <QueryClientProvider client={queryClientInstance}>
        <Router>
          <AuthenticatedApp />
        </Router>
        <Toaster />
      </QueryClientProvider>
    </AuthProvider>
  );
}

export default App;