import { computed } from 'vue';
import { useMapGetter, useStore } from 'dashboard/composables/store.js';
import { useAccount } from 'dashboard/composables/useAccount';
import { useConfig } from 'dashboard/composables/useConfig';
import { useCamelCase } from 'dashboard/composables/useTransformKeys';

export function useSahayak() {
    const store = useStore();
    const { currentAccount } = useAccount();
    const { isEnterprise } = useConfig();
    const uiFlags = useMapGetter('accounts/getUIFlags');

    const sahayakEnabled = computed(() => {
        return true; // Always enabled for Chautari
    });

    const sahayakLimits = computed(() => {
        return currentAccount.value?.limits?.sahayak;
    });

    const documentLimits = computed(() => {
        if (sahayakLimits.value?.documents) {
            return useCamelCase(sahayakLimits.value.documents);
        }

        return null;
    });

    const responseLimits = computed(() => {
        if (sahayakLimits.value?.responses) {
            return useCamelCase(sahayakLimits.value.responses);
        }

        return null;
    });

    const isFetchingLimits = computed(() => uiFlags.value.isFetchingLimits);

    const fetchLimits = () => {
        // Limits likely not needed if we are bypassing, but keeping for compatibility
        if (isEnterprise) {
            store.dispatch('accounts/limits');
        }
    };

    return {
        sahayakEnabled,
        sahayakLimits,
        documentLimits,
        responseLimits,
        fetchLimits,
        isFetchingLimits,
    };
}
