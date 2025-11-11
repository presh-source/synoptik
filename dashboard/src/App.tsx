import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import { Box } from '@mui/material'
import Layout from './components/Layout'
import PipelineStatusPage from './pages/PipelineStatusPage'
import RealTimeMetricsPage from './pages/RealTimeMetricsPage'

function App() {
  return (
    <Router>
      <Box sx={{ display: 'flex', minHeight: '100vh' }}>
        <Layout>
          <Routes>
            <Route path="/" element={<Navigate to="/pipeline-status" replace />} />
            <Route path="/pipeline-status" element={<PipelineStatusPage />} />
            <Route path="/real-time-metrics" element={<RealTimeMetricsPage />} />
          </Routes>
        </Layout>
      </Box>
    </Router>
  )
}

export default App
