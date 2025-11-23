// vite.config.js
import { defineConfig } from 'vite';
import { createHtmlPlugin } from 'vite-plugin-html';

export default defineConfig({
    plugins: [
        createHtmlPlugin({
            inject: {
                data: {
                    // Vite will replace this token with the capitalized value
                    VITE_PROJECT_NAME_CAP: (process.env.VITE_PROJECT_NAME || '')
                        .replace(/^./, (c) => c.toUpperCase()),
                },
            },
        }),
    ],
});
