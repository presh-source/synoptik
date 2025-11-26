import { BrowserRouter as Router, Routes, Route, useLocation } from 'react-router-dom'
import { Box } from '@mui/material'
import { useEffect } from 'react'
import Layout from './components/Layout'
import HomePage from './pages/HomePage'
import { logNavigation } from './utils/logger'

// Component to track navigation
function NavigationTracker() {
  const location = useLocation()

  useEffect(() => {
    logNavigation(location.pathname, {
      extra: {
        search: location.search,
        hash: location.hash,
      },
    })
  }, [location])

  return null
}

function App() {
  return (
    <Router>
      <NavigationTracker />
      <Box sx={{ display: 'flex', minHeight: '100vh' }}>
        <Layout>
          <Routes>
            <Route path="/" element={<HomePage />} />
          </Routes>
        </Layout>
      </Box>
    </Router>
  )
}

export default App
