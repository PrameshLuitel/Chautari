import { frontendURL } from '../../../helper/URLHelper';
import InventoryIndex from './Index.vue';

export const routes = [
    {
        path: frontendURL('accounts/:accountId/inventory'),
        name: 'inventory_dashboard_index',
        component: InventoryIndex,
        meta: {
            permissions: ['administrator', 'agent'],
        },
    },
];
