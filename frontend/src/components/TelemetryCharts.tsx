import { useQuery } from '@apollo/client';
import { Box, Card, CardContent, CircularProgress, Grid, Typography, useTheme } from '@mui/material';
import { CartesianGrid, Legend, Line, LineChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts';
import { GET_TELEMETRY_AGGREGATION } from '../graphql/queries';
import { formatTimestamp } from '../utils/formatting';

interface TelemetryChartsProps {
    organisation: string;
    entity: string;
}

export default function TelemetryCharts({ organisation, entity }: TelemetryChartsProps) {
    const theme = useTheme();

    // Calculate time range (last 24 hours)
    const end = new Date().toISOString();
    const start = new Date(Date.now() - 24 * 60 * 60 * 1000).toISOString();

    const { data: retrievalData, loading: retrievalLoading } = useQuery(GET_TELEMETRY_AGGREGATION, {
        variables: {
            organisation,
            entity,
            metricType: 'retrievals',
            start,
            end
        },
        fetchPolicy: 'network-only',
    });

    const { data: requestData, loading: requestLoading } = useQuery(GET_TELEMETRY_AGGREGATION, {
        variables: {
            organisation,
            entity,
            metricType: 'requests',
            start,
            end
        },
        fetchPolicy: 'network-only',
    });

    const { data: runData, loading: runLoading } = useQuery(GET_TELEMETRY_AGGREGATION, {
        variables: {
            organisation,
            entity,
            metricType: 'runs',
            start,
            end
        },
        fetchPolicy: 'network-only',
    });

    if (retrievalLoading || requestLoading || runLoading) {
        return (
            <Box display="flex" justifyContent="center" p={4}>
                <CircularProgress />
            </Box>
        );
    }

    const retrievals = retrievalData?.getTelemetryAggregation || [];
    const requests = requestData?.getTelemetryAggregation || [];
    const runs = runData?.getTelemetryAggregation || [];

    // Sort by createdAt
    const sortedRetrievals = [...retrievals].sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
    const sortedRequests = [...requests].sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());
    const sortedRuns = [...runs].sort((a, b) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime());

    return (
        <Grid container spacing={3} mt={1}>
            {/* Retrievals Chart */}
            <Grid item xs={12} lg={6}>
                <Card sx={{ height: '100%', minHeight: 400 }}>
                    <CardContent>
                        <Typography variant="h6" gutterBottom>Items Retrieved (Last 24h)</Typography>
                        <ResponsiveContainer width="100%" height={300}>
                            <LineChart data={sortedRetrievals}>
                                <CartesianGrid strokeDasharray="3 3" />
                                <XAxis
                                    dataKey="createdAt"
                                    tickFormatter={(val) => new Date(val).getHours() + ':00'}
                                />
                                <YAxis />
                                <Tooltip
                                    labelFormatter={(val) => formatTimestamp(val)}
                                />
                                <Legend />
                                <Line
                                    type="monotone"
                                    dataKey="totalRetrieval"
                                    name="Total Items"
                                    stroke={theme.palette.primary.main}
                                    strokeWidth={2}
                                />
                                <Line
                                    type="monotone"
                                    dataKey="avgRetrieval"
                                    name="Avg per Request"
                                    stroke={theme.palette.secondary.main}
                                />
                            </LineChart>
                        </ResponsiveContainer>
                    </CardContent>
                </Card>
            </Grid>

            {/* Requests & Errors Chart */}
            <Grid item xs={12} lg={6}>
                <Card sx={{ height: '100%', minHeight: 400 }}>
                    <CardContent>
                        <Typography variant="h6" gutterBottom>Requests & Errors</Typography>
                        <ResponsiveContainer width="100%" height={300}>
                            <LineChart data={sortedRequests}>
                                <CartesianGrid strokeDasharray="3 3" />
                                <XAxis
                                    dataKey="createdAt"
                                    tickFormatter={(val) => new Date(val).getHours() + ':00'}
                                />
                                <YAxis yAxisId="left" />
                                <YAxis yAxisId="right" orientation="right" />
                                <Tooltip
                                    labelFormatter={(val) => formatTimestamp(val)}
                                />
                                <Legend />
                                <Line
                                    yAxisId="left"
                                    type="monotone"
                                    dataKey="count"
                                    name="Total Requests"
                                    stroke={theme.palette.info.main}
                                    strokeWidth={2}
                                />
                                <Line
                                    yAxisId="right"
                                    type="monotone"
                                    dataKey="errorCount"
                                    name="Errors"
                                    stroke={theme.palette.error.main}
                                />
                            </LineChart>
                        </ResponsiveContainer>
                    </CardContent>
                </Card>
            </Grid>

            {/* Lambda Performance Chart */}
            <Grid item xs={12}>
                <Card sx={{ height: '100%', minHeight: 400 }}>
                    <CardContent>
                        <Typography variant="h6" gutterBottom>Lambda Performance</Typography>
                        <ResponsiveContainer width="100%" height={300}>
                            <LineChart data={sortedRuns}>
                                <CartesianGrid strokeDasharray="3 3" />
                                <XAxis
                                    dataKey="createdAt"
                                    tickFormatter={(val) => new Date(val).getHours() + ':00'}
                                />
                                <YAxis yAxisId="left" label={{ value: 'Duration (ms)', angle: -90, position: 'insideLeft' }} />
                                <YAxis yAxisId="right" orientation="right" label={{ value: 'Memory (MB)', angle: 90, position: 'insideRight' }} />
                                <Tooltip
                                    labelFormatter={(val) => formatTimestamp(val)}
                                />
                                <Legend />
                                <Line
                                    yAxisId="left"
                                    type="monotone"
                                    dataKey="avgDuration"
                                    name="Avg Duration (ms)"
                                    stroke={theme.palette.warning.main}
                                    strokeWidth={2}
                                />
                                <Line
                                    yAxisId="right"
                                    type="monotone"
                                    dataKey="avgMemoryUsed"
                                    name="Avg Memory (MB)"
                                    stroke={theme.palette.success.main}
                                />
                            </LineChart>
                        </ResponsiveContainer>
                    </CardContent>
                </Card>
            </Grid>
        </Grid>
    );
}
