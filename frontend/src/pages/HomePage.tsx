import { Box, Container, Grid, Typography, Tab, Tabs } from '@mui/material';
import FolderIcon from '@mui/icons-material/Folder';
import PersonIcon from '@mui/icons-material/Person';
import SpeedIcon from '@mui/icons-material/Speed';
import CrawlerMetrics from '../components/CrawlerMetrics';
import TelemetryCharts from '../components/TelemetryCharts';
import { useState } from 'react';

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function CustomTabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;

  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`simple-tabpanel-${index}`}
      aria-labelledby={`simple-tab-${index}`}
      {...other}
    >
      {value === index && (
        <Box sx={{ py: 3 }}>
          {children}
        </Box>
      )}
    </div>
  );
}

export default function HomePage() {
  const [value, setValue] = useState(0);

  const handleChange = (_event: React.SyntheticEvent, newValue: number) => {
    setValue(newValue);
  };

  return (
    <Container maxWidth="xl">
      <Box py={{ xs: 2, md: 4 }}>
        <Box display="flex" alignItems="center" mb={{ xs: 2, md: 4 }}>
          <SpeedIcon sx={{ fontSize: { xs: 24, md: 32 }, mr: { xs: 1, md: 2 }, color: 'primary.main' }} />
          <Typography variant="h4" component="h1" sx={{ fontSize: { xs: '1.5rem', md: '2.125rem' } }}>
            Crawler Performance Metrics
          </Typography>
        </Box>

        <Grid container spacing={3} mb={4}>
          <Grid item xs={12} md={6}>
            <CrawlerMetrics
              title="GitHub Repository Crawler"
              variables={{ organisation: 'github', entity: 'repository' }}
              icon={<FolderIcon color="primary" />}
            />
          </Grid>
          <Grid item xs={12} md={6}>
            <CrawlerMetrics
              title="GitHub User Crawler"
              variables={{ organisation: 'github', entity: 'user' }}
              icon={<PersonIcon color="success" />}
            />
          </Grid>
        </Grid>

        <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
          <Tabs value={value} onChange={handleChange} aria-label="telemetry tabs">
            <Tab label="Repositories" />
            <Tab label="Users" />
          </Tabs>
        </Box>
        <CustomTabPanel value={value} index={0}>
          <TelemetryCharts organisation="github" entity="repository" />
        </CustomTabPanel>
        <CustomTabPanel value={value} index={1}>
          <TelemetryCharts organisation="github" entity="user" />
        </CustomTabPanel>
      </Box>
    </Container>
  );
}
