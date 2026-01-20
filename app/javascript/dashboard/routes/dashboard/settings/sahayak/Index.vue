<script setup>
import { ref, computed, onMounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { storeToRefs } from 'pinia';
import { useAlert } from 'dashboard/composables';
import { useAccount } from 'dashboard/composables/useAccount';
import { useSahayak } from 'dashboard/composables/useSahayak';
import { useConfig } from 'dashboard/composables/useConfig';
import { useSahayakConfigStore } from 'dashboard/store/sahayak/preferences';

import SettingsLayout from '../SettingsLayout.vue';
import BaseSettingsHeader from '../components/BaseSettingsHeader.vue';
import SectionLayout from '../account/components/SectionLayout.vue';
import ModelSelector from './components/ModelSelector.vue';
import FeatureToggle from './components/FeatureToggle.vue';
// No Paywall component needed for Sahayak

const { t } = useI18n();
const { sahayakEnabled } = useSahayak();
const { isEnterprise, enterprisePlanName } = useConfig();
const { isOnChatwootCloud } = useAccount();

const sahayakConfigStore = useSahayakConfigStore();
const { uiFlags } = storeToRefs(sahayakConfigStore);

const isLoading = computed(() => uiFlags.value.isFetching);

const modelFeatures = computed(() => [
  {
    key: 'editor',
    title: t('SAHAYAK_SETTINGS.MODEL_CONFIG.EDITOR.TITLE'),
    description: t('SAHAYAK_SETTINGS.MODEL_CONFIG.EDITOR.DESCRIPTION'),
  },
  {
    key: 'assistant',
    title: t('SAHAYAK_SETTINGS.MODEL_CONFIG.ASSISTANT.TITLE'),
    description: t('SAHAYAK_SETTINGS.MODEL_CONFIG.ASSISTANT.DESCRIPTION'),
    enterprise: false, // Sahayak is free
  },
  {
    key: 'copilot',
    title: t('SAHAYAK_SETTINGS.MODEL_CONFIG.COPILOT.TITLE'),
    description: t('SAHAYAK_SETTINGS.MODEL_CONFIG.COPILOT.DESCRIPTION'),
    enterprise: false, // Sahayak is free
  },
]);

const featureToggles = computed(() => [
  {
    key: 'label_suggestion',
  },
  {
    key: 'help_center_search',
    enterprise: false, // Sahayak is free
  },
  {
    key: 'audio_transcription',
    enterprise: false, // Sahayak is free
  },
]);

const { groqConfig } = storeToRefs(sahayakConfigStore);

const groqApiKey = ref('');
const isApiKeyVisible = ref(false);

const toggleApiKeyVisibility = () => {
  isApiKeyVisible.value = !isApiKeyVisible.value;
};
const groqApiEndpoint = ref('');
const groqModelName = computed({
  get: () => groqConfig.value.ai_model_name,
  set: value => {
    groqConfig.value.ai_model_name = value;
  },
});

watch(
  groqConfig,
  newConfig => {
    if (newConfig) {
      groqApiKey.value = newConfig.api_key || '';
      groqApiEndpoint.value =
        newConfig.api_endpoint || 'https://api.groq.com/openai/v1';
    }
  },
  { immediate: true }
);

const groqModels = computed(() => sahayakConfigStore.getGroqModels);

const shouldShowFeature = feature => {
  return true;
};

const isFeatureAccessible = feature => {
  return true;
};

async function handleGroqConfigSave() {
  try {
    await sahayakConfigStore.updatePreferences({
      groq_config: {
        api_key: groqApiKey.value,
        api_endpoint: groqApiEndpoint.value,
        ai_model_name: groqModelName.value, // Use ai_model_name
      },
    });
    useAlert(t('SAHAYAK_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('SAHAYAK_SETTINGS.API.ERROR'));
  }
}

async function handleFeatureToggle({ feature, enabled }) {
  try {
    await sahayakConfigStore.updatePreferences({
      sahayak_features: { [feature]: enabled },
    });
    useAlert(t('SAHAYAK_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('SAHAYAK_SETTINGS.API.ERROR'));
    sahayakConfigStore.fetch();
  }
}

async function handleModelChange({ feature, model }) {
  try {
    await sahayakConfigStore.updatePreferences({
      sahayak_models: { [feature]: model },
    });
    useAlert(t('SAHAYAK_SETTINGS.API.SUCCESS'));
  } catch (error) {
    useAlert(t('SAHAYAK_SETTINGS.API.ERROR'));
    sahayakConfigStore.fetch();
  }
}

onMounted(() => {
  sahayakConfigStore.fetch();
});
</script>

<template>
  <SettingsLayout
    :is-loading="isLoading"
    :no-records-message="t('SAHAYAK_SETTINGS.NOT_ENABLED')"
    :loading-message="t('SAHAYAK_SETTINGS.LOADING')"
  >
    <template #header>
      <BaseSettingsHeader
        :title="t('SAHAYAK_SETTINGS.TITLE')"
        :description="t('SAHAYAK_SETTINGS.DESCRIPTION')"
        icon-name="i-lucide-bot"
      />
    </template>
    <template #body>
      <div v-if="sahayakEnabled" class="flex flex-col gap-1">
        <!-- Groq Configuration Section -->
        <SectionLayout
          :title="t('SAHAYAK_SETTINGS.GROQ_CONFIG.TITLE')"
          :description="t('SAHAYAK_SETTINGS.GROQ_CONFIG.DESCRIPTION')"
        >
          <div class="grid gap-4 max-w-2xl">
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('SAHAYAK_SETTINGS.GROQ_CONFIG.API_KEY.LABEL') }}
              </label>
              <div class="relative flex items-center">
                <input
                  v-model="groqApiKey"
                  :type="isApiKeyVisible ? 'text' : 'password'"
                  class="w-full pl-3 pr-10 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-2 focus:ring-2 focus:ring-n-iris-10 outline-none"
                  :placeholder="t('SAHAYAK_SETTINGS.GROQ_CONFIG.API_KEY.PLACEHOLDER')"
                />
                <button
                  type="button"
                  class="absolute right-3 p-1 text-n-slate-10 hover:text-n-slate-12 transition-colors cursor-pointer"
                  @click="toggleApiKeyVisibility"
                >
                  <Icon
                    :icon="isApiKeyVisible ? 'i-lucide-eye-off' : 'i-lucide-eye'"
                    class="size-4"
                  />
                </button>
              </div>
            </div>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('SAHAYAK_SETTINGS.GROQ_CONFIG.API_ENDPOINT.LABEL') }}
              </label>
              <input
                v-model="groqApiEndpoint"
                type="text"
                class="w-full px-3 py-2 text-sm border rounded-lg border-n-weak bg-n-alpha-2 focus:ring-2 focus:ring-n-iris-10 outline-none"
                :placeholder="t('SAHAYAK_SETTINGS.GROQ_CONFIG.API_ENDPOINT.PLACEHOLDER')"
              />
            </div>
            <div class="flex flex-col gap-2">
              <label class="text-sm font-medium text-n-slate-12">
                {{ t('SAHAYAK_SETTINGS.GROQ_CONFIG.MODEL.LABEL') }}
              </label>
              <select
                v-model="groqModelName"
                class="w-full h-10 px-3 text-sm border rounded-md bg-n-slate-1 border-n-slate-4 focus:outline-none focus:ring-2 focus:ring-n-brand focus:border-transparent"
              >
                <option
                  v-for="model in groqModels"
                  :key="model"
                  :value="model"
                >
                  {{ model }}
                </option>
              </select>
            </div>
            <div class="flex justify-end pt-2">
              <button
                class="px-4 py-2 text-sm font-medium text-white bg-n-iris-10 rounded-lg hover:bg-n-iris-11 transition-colors"
                @click="handleGroqConfigSave"
              >
                {{ t('SAHAYAK_SETTINGS.GROQ_CONFIG.SAVE_BUTTON') }}
              </button>
            </div>
          </div>
        </SectionLayout>

        <!-- Model Configuration Section -->
        <SectionLayout
          :title="t('SAHAYAK_SETTINGS.MODEL_CONFIG.TITLE')"
          :description="t('SAHAYAK_SETTINGS.MODEL_CONFIG.DESCRIPTION')"
          with-border
        >
          <div class="grid gap-4">
            <ModelSelector
              v-for="feature in modelFeatures"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              :title="feature.title"
              :description="feature.description"
              @change="handleModelChange"
            />
          </div>
        </SectionLayout>

        <!-- Features Section -->
        <SectionLayout
          :title="t('SAHAYAK_SETTINGS.FEATURES.TITLE')"
          :description="t('SAHAYAK_SETTINGS.FEATURES.DESCRIPTION')"
          with-border
        >
          <div class="grid gap-4">
            <FeatureToggle
              v-for="feature in featureToggles"
              v-show="shouldShowFeature(feature)"
              :key="feature.key"
              :is-allowed="isFeatureAccessible(feature)"
              :feature-key="feature.key"
              @change="handleFeatureToggle"
              @model-change="handleModelChange"
            />
          </div>
        </SectionLayout>
      </div>
      <div v-else>
         <div class="p-4 rounded-xl border border-n-weak bg-n-solid-1">
            <p>Sahayak is not enabled for this account.</p>
         </div>
      </div>
    </template>
  </SettingsLayout>
</template>
