import { defineStore } from 'pinia';
import SahayakPreferencesAPI from 'dashboard/api/sahayak/preferences';

export const useSahayakConfigStore = defineStore('sahayakConfig', {
    state: () => ({
        providers: {},
        models: {},
        features: {},
        groqConfig: {},
        uiFlags: {
            isFetching: false,
        },
    }),

    getters: {
        getProviders: state => state.providers,
        getModels: state => state.models,
        getFeatures: state => state.features,
        getGroqConfig: state => state.groqConfig,
        getUIFlags: state => state.uiFlags,
        getModelsForFeature: state => featureKey => {
            const feature = state.features[featureKey];
            const models = feature?.models || [];

            const providerOrder = { openai: 0, anthropic: 1, gemini: 2, groq: 3 };

            return [...models].sort((a, b) => {
                // Move coming_soon items to the end
                if (a.coming_soon && !b.coming_soon) return 1;
                if (!a.coming_soon && b.coming_soon) return -1;

                // Sort by provider
                const providerA = providerOrder[a.provider] ?? 999;
                const providerB = providerOrder[b.provider] ?? 999;
                if (providerA !== providerB) return providerA - providerB;

                // Sort by credit_multiplier (highest first) - though credits might not matter now
                return (b.credit_multiplier || 0) - (a.credit_multiplier || 0);
            });
        },
        getDefaultModelForFeature: state => featureKey => {
            const feature = state.features[featureKey];
            return feature?.default || null;
        },
        getSelectedModelForFeature: state => featureKey => {
            const feature = state.features[featureKey];
            return feature?.selected || feature?.default || null;
        },
        getGroqModels: state => {
            return Object.keys(state.models).filter(
                modelKey => state.models[modelKey].provider === 'groq'
            );
        },
    },

    actions: {
        async fetch() {
            this.uiFlags.isFetching = true;
            try {
                const response = await SahayakPreferencesAPI.get();
                this.providers = response.data.providers || {};
                this.models = response.data.models || {};
                this.features = response.data.features || {};
                this.groqConfig = response.data.groq_config || {};
            } catch (error) {
                // Ignore error
            } finally {
                this.uiFlags.isFetching = false;
            }
        },

        async updatePreferences(data) {
            const response = await SahayakPreferencesAPI.updatePreferences(data);
            this.providers = response.data.providers || {};
            this.models = response.data.models || {};
            this.features = response.data.features || {};
            this.groqConfig = response.data.groq_config || {};
        },
    },
});
