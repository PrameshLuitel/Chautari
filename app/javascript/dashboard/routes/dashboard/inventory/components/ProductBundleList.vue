<script setup>
import { ref, onMounted } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  accountId: { type: [String, Number], required: true }
});

const emit = defineEmits(['add', 'edit']);

const bundles = ref([]);
const isFetching = ref(false);

const fetchBundles = async () => {
  isFetching.value = true;
  try {
    const response = await window.axios.get(`/api/v1/accounts/${props.accountId}/product_bundles`);
    bundles.value = response.data;
  } catch (error) {
    console.error(error);
  } finally {
    isFetching.value = false;
  }
};

const deleteBundle = async (id) => {
  if (!confirm('Are you sure you want to remove this bundle?')) return;
  try {
    await window.axios.delete(`/api/v1/accounts/${props.accountId}/product_bundles/${id}`);
    bundles.value = bundles.value.filter(b => b.id !== id);
    useAlert('Bundle removed');
  } catch (error) {
    useAlert('Could not delete bundle');
  }
};

onMounted(() => {
  fetchBundles();
});
</script>

<template>
  <div class="flex flex-col gap-6">
    <!-- Empty State -->
    <div v-if="!bundles.length && !isFetching" class="flex flex-col items-center justify-center py-20 text-n-slate-11">
      <div class="size-16 mb-4 rounded-full bg-n-alpha-3 flex items-center justify-center">
        <div class="i-lucide-layers size-8 text-n-slate-11" />
      </div>
      <h2 class="text-xl font-medium text-n-slate-12 mb-2">No bundles yet</h2>
      <p class="text-n-slate-10 max-w-sm text-center mb-6">
        Create bundles to group products together for special offers.
      </p>
      <Button
        label="Create Bundle"
        icon="i-lucide-plus"
        @click="emit('add')"
      />
    </div>

    <!-- Bundle Grid -->
    <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <div 
        v-for="bundle in bundles" 
        :key="bundle.id"
        class="bg-white dark:bg-n-solid-2 border border-n-weak rounded-xl overflow-hidden flex flex-col hover:shadow-md transition-shadow"
      >
        <div class="p-4 flex flex-1 flex-col">
          <div class="flex items-start justify-between mb-2">
            <h3 class="font-bold text-n-slate-12 text-lg truncate">{{ bundle.name }}</h3>
            <span class="bg-n-brand/10 text-n-brand text-xs font-bold px-2 py-1 rounded">
              {{ bundle.price ? `NPR ${bundle.price}` : 'Dynamic Price' }}
            </span>
          </div>
          
          <p class="text-n-slate-11 text-sm line-clamp-2 mb-4">
            {{ bundle.description || 'No description provided.' }}
          </p>

          <div class="flex flex-wrap gap-2 mb-4">
            <div 
              v-for="product in bundle.products" 
              :key="product.id"
              class="px-2 py-1 bg-n-alpha-2 rounded text-xs text-n-slate-11 border border-n-weak"
            >
              {{ product.name }}
            </div>
          </div>
          
          <!-- Actions -->
          <div class="flex justify-end gap-2 pt-4 border-t border-n-weak mt-auto">
            <Button
              variant="outline"
              color="slate"
              size="sm"
              icon="i-lucide-trash-2"
              @click="deleteBundle(bundle.id)"
            />
            <Button
              variant="outline"
              size="sm"
              icon="i-lucide-pencil"
              label="Edit"
              @click="emit('edit', bundle)"
            />
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
