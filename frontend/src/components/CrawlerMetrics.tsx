import { useQuery, useSubscription } from '@apollo/client';
import { Box, Card, CardContent, CircularProgress, Typography } from '@mui/material';

import { useEffect } from 'react';
import { GET_CRAWLER_STATE } from '../graphql/queries';
import { ON_CRAWLER_COMPLETED } from '../graphql/subscriptions';
import { formatTimestamp } from '../utils/formatting';

interface CrawlerMetricsProps {
    title: string;

    variables: Record<string, any>;
    icon?: React.ReactNode;
}

export default function CrawlerMetrics({ title, variables, icon }: CrawlerMetricsProps) {
    // Initial data fetch
    const { data, loading, error, refetch } = useQuery(GET_CRAWLER_STATE, {
        variables: variables,
        fetchPolicy: 'network-only',
    });

    // Real-time subscription
    const { data: subscriptionData } = useSubscription(ON_CRAWLER_COMPLETED, {
        variables: variables,
    });

    // Refetch when subscription data arrives
    useEffect(() => {
        if (subscriptionData) {
            refetch();
        }
    }, [subscriptionData, refetch]);

    if (loading) {
        return (
            <Card sx={{ height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 200 }}>
                <CircularProgress />
            </Card>
        );
    }

    if (error) {
        return (
            <Card sx={{ height: '100%', minHeight: 200 }}>
                <CardContent>
                    <Typography color="error">Error loading metrics</Typography>
                    <Typography variant="caption">{error.message}</Typography>
                </CardContent>
            </Card>
        );
    }

    // Use generic crawler key
    const metrics = data?.getCrawlerState || { lastProcessedId: 0, totalProcessed: 0, updatedAt: null };

    return (
        <Card sx={{ height: '100%' }}>
            <CardContent>
                <Box display="flex" alignItems="center" mb={{ xs: 2, md: 3 }}>
                    {icon && <Box mr={1} display="flex" alignItems="center">{icon}</Box>}
                    <Typography variant="h6" component="div" fontWeight="bold" sx={{ fontSize: { xs: '1rem', md: '1.25rem' } }}>
                        {title}
                    </Typography>
                </Box>

                <Box display="flex" flexDirection={{ xs: 'column', sm: 'row' }} justifyContent="space-between" gap={{ xs: 2, sm: 0 }}>
                    <Box>
                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                            Last Processed ID
                        </Typography>
                        <Typography
                            variant="h4"
                            color="primary"
                            fontWeight="medium"
                            sx={{
                                fontSize: { xs: '1.5rem', md: '2rem', lg: '2.125rem' },
                                wordBreak: 'break-word'
                            }}
                        >
                            {metrics.lastProcessedId.toLocaleString()}
                        </Typography>
                    </Box>

                    <Box textAlign={{ xs: 'left', sm: 'right' }}>
                        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                            Total Processed
                        </Typography>
                        <Typography
                            variant="h4"
                            color="primary"
                            fontWeight="medium"
                            sx={{
                                fontSize: { xs: '1.5rem', md: '2rem', lg: '2.125rem' },
                                wordBreak: 'break-word'
                            }}
                        >
                            {metrics.totalProcessed.toLocaleString()}
                        </Typography>
                    </Box>
                </Box>
                {metrics.updatedAt && (
                    <Box mt={2}>
                        <Typography variant="caption" color="text.secondary">
                            Updated: {formatTimestamp(metrics.updatedAt)}
                        </Typography>
                    </Box>
                )}
            </CardContent>
        </Card>
    );
}
