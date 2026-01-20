import { frontendURL } from '../../../../helper/URLHelper';
import SettingsWrapper from '../SettingsWrapper.vue';
import Index from './Index.vue';

export default {
    routes: [
        {
            path: frontendURL('accounts/:accountId/settings/sahayak'),
            component: SettingsWrapper,
            props: {
                headerTitle: 'SAHAYAK_SETTINGS.TITLE',
                icon: 'i-lucide-bot',
                showNewButton: false,
            },
            children: [
                {
                    path: '',
                    name: 'sahayak_settings_index',
                    component: Index,
                    meta: {
                        permissions: ['administrator'],
                        // Removed enterprise/feature flag checks
                    },
                },
            ],
        },
    ],
};
