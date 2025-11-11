# Synoptik Dashboard

A real-time observability dashboard for monitoring the Synoptik platform.

## Features

- **Pipeline Status Dashboard**: Monitor Cold Path, Hot Path, and Scrubber Path pipelines
- **Real-Time Metrics**: View trending repositories, language distribution, and creation trends
- **Auto-refresh**: Automatic data updates every 30-60 seconds
- **Responsive Design**: Works on desktop and mobile devices

## Tech Stack

- **React 18** with TypeScript
- **Vite** for fast development and building
- **Material-UI (MUI)** for UI components
- **React Query** for server state management
- **React Router** for navigation
- **Recharts** for data visualization
- **Axios** for API calls

## Getting Started

### Prerequisites

- Node.js 18+ and npm

### Installation

```bash
npm install
```

### Development

```bash
npm run dev
```

The application will be available at `http://localhost:3000`.

### Environment Variables

Create a `.env` file based on `.env.example`:

```bash
VITE_API_URL=http://localhost:8080
```

### Building for Production

```bash
npm run build
```

The built files will be in the `dist` directory.

### Preview Production Build

```bash
npm run preview
```

## Project Structure

```
dashboard/
├── src/
│   ├── api/              # API client and endpoints
│   ├── components/       # Reusable components
│   ├── hooks/            # Custom React hooks
│   ├── pages/            # Page components
│   ├── types/            # TypeScript type definitions
│   ├── App.tsx           # Main app component
│   ├── main.tsx          # Entry point
│   └── theme.ts          # MUI theme configuration
├── public/               # Static assets
├── index.html            # HTML template
├── package.json          # Dependencies
├── tsconfig.json         # TypeScript configuration
└── vite.config.ts        # Vite configuration
```

## API Integration

The dashboard connects to the backend API endpoints:

- `GET /api/pipeline-status` - Pipeline status and metrics
- `GET /api/metrics/realtime` - Real-time metrics with filters
- `GET /api/repositories/trending` - Trending repositories

## Development Guidelines

- Use TypeScript for type safety
- Follow React hooks best practices
- Use Material-UI components for consistency
- Implement proper error handling
- Add loading states for async operations
- Keep components small and focused

## Deployment

### LocalStack (Local Development)

For local development and testing with LocalStack:

```bash
# Start LocalStack (from project root)
docker-compose -f docker-compose.localstack.yml up -d

# Deploy dashboard to LocalStack
./deploy-localstack.sh
```

Access the dashboard at:
- http://localhost:4566/synoptik-dashboard-local/index.html

See [../LOCALSTACK_SETUP.md](../LOCALSTACK_SETUP.md) for complete LocalStack setup guide.

### AWS (Production)

For production deployment to AWS:

```bash
# Deploy to AWS (requires Terraform infrastructure to be set up)
./deploy.sh

# Or deploy to specific environment
./deploy.sh prod
```

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed AWS deployment instructions.

### CI/CD

The project includes GitHub Actions workflow for automated deployments. See `.github/workflows/deploy.yml` for configuration.
