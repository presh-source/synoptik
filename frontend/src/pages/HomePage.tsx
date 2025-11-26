import { Box, Container, Grid, Typography } from '@mui/material';
import FolderIcon from '@mui/icons-material/Folder';
import PersonIcon from '@mui/icons-material/Person';
import SpeedIcon from '@mui/icons-material/Speed';
import CrawlerMetrics from '../components/CrawlerMetrics';

export default function HomePage() {
  return (
    <Container maxWidth="lg">
      <Box py={{ xs: 2, md: 4 }}>
        <Box display="flex" alignItems="center" mb={{ xs: 2, md: 4 }}>
          <SpeedIcon sx={{ fontSize: { xs: 24, md: 32 }, mr: { xs: 1, md: 2 }, color: 'primary.main' }} />
          <Typography variant="h4" component="h1" sx={{ fontSize: { xs: '1.5rem', md: '2.125rem' } }}>
            Crawler Performance Metrics
          </Typography>
        </Box>

        <Grid container spacing={3}>
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
      </Box>
    </Container>
  );
}
