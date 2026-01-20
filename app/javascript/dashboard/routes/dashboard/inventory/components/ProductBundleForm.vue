<script setup>
import { ref, onMounted } from 'vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';

const props = defineProps({
  accountId: { type: [String, Number], required: true },
  bundle: { type: Object, default: () => ({ name: '', description: '', price: null, product_ids: [] }) }
});

const emit = defineEmits(['save', 'cancel']);

const form = ref({ ...props.bundle });
if (!form.value.product_ids) form.value.product_ids = props.bundle.products?.map(p => p.id) || [];

const allProducts = ref([]);
const isFetchingProducts = ref(false);

const fetchProducts = async () => {
  isFetchingProducts.value = true;
  try {
    const response = await window.axios.get(`/api/v1/accounts/${props.accountId}/products`);
    allProducts.value = response.data;
  } catch (error) {
    console.error(error);
  } finally {
    isFetchingProducts.value = false;
  }
};

const toggleProduct = (productId) => {
  const index = form.value.product_ids.indexOf(productId);
  if (index === -1) {
    form.value.product_ids.push(productId);
  } else {
    form.value.product_ids.splice(index, 1);
  }
};

const handleSubmit = async () => {
  if (!form.value.name) {
    useAlert('Bundle name is required');
    return;
  }
  if (form.value.product_ids.length === 0) {
    useAlert('Select at least one product for the bundle');
    return;
  }

  try {
    let response;
    if (form.value.id) {
      response = await window.axios.patch(`/api/v1/accounts/${props.accountId}/product_bundles/${form.value.id}`, {
        product_bundle: form.value
      });
    } else {
      response = await window.axios.post(`/api/v1/accounts/${props.accountId}/product_bundles`, {
        product_bundle: form.value
      });
    }
    emit('save', response.data);
    useAlert(form.value.id ? 'Bundle updated' : 'Bundle created');
  } catch (error) {
    useAlert('Could not save bundle');
  }
};

onMounted(() => {
  fetchProducts();
});
</script>

<template>
  <div class="flex flex-col gap-6 p-6 min-w-[500px]">
    <div class="flex flex-col items-start">
      <h2 class="text-xl font-medium text-n-slate-12">
        {{ form.id ? 'Edit Bundle' : 'Create New Bundle' }}
      </h2>
      <p class="text-n-slate-10 text-sm mt-1">Group products together for a special offer</p>
    </div>

    <div class="flex flex-col gap-4">
      <!-- Name -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-11">Bundle Name</label>
        <input 
          v-model="form.name" 
          type="text" 
          placeholder="e.g. Starter Pack" 
          class="w-full px-3 py-2 bg-n-solid-1 border border-n-weak rounded-md text-sm focus:outline-none focus:border-n-brand transition-colors text-n-slate-12"
        />
      </div>

      <!-- Description -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-11">Description</label>
        <textarea 
          v-model="form.description" 
          placeholder="Describe this bundle..." 
          class="w-full px-3 py-2 bg-n-solid-1 border border-n-weak rounded-md text-sm focus:outline-none focus:border-n-brand transition-colors text-n-slate-12 min-h-[80px] resize-none"
        />
      </div>

      <!-- Bundle Price (Optional) -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-11">Bundle Price (Optional)</label>
        <div class="flex gap-2">
          <input 
            v-model.number="form.price" 
            type="number" 
            placeholder="Defaults to sum of products" 
            class="flex-1 px-3 py-2 bg-n-solid-1 border border-n-weak rounded-md text-sm focus:outline-none focus:border-n-brand transition-colors text-n-slate-12"
          />
          <div class="px-3 py-2 bg-n-alpha-2 border border-n-weak rounded-md text-sm text-n-slate-10">
            NPR
          </div>
        </div>
        <p class="text-xs text-n-slate-9 italic">Leave empty to use the total sum of individual products.</p>
      </div>

      <!-- Product Selection -->
      <div class="flex flex-col gap-1.5">
        <label class="text-sm font-medium text-n-slate-11">Select Products</label>
        <div class="border border-n-weak rounded-md max-h-[200px] overflow-y-auto divide-y divide-n-weak">
          <div 
            v-for="product in allProducts" 
            :key="product.id"
            class="flex items-center gap-3 p-2 hover:bg-n-alpha-1 cursor-pointer transition-colors"
            @click="toggleProduct(product.id)"
          >
            <div 
              class="size-4 border rounded flex items-center justify-center transition-colors"
              :class="form.product_ids.includes(product.id) ? 'bg-n-brand border-n-brand text-white' : 'border-n-slate-6'"
            >
              <div v-if="form.product_ids.includes(product.id)" class="i-lucide-check size-3" />
            </div>
            <div class="flex-1">
              <p class="text-sm text-n-slate-12">{{ product.name }}</p>
              <p class="text-xs text-n-slate-10">{{ product.currency }} {{ product.cost }}</p>
            </div>
          </div>
          <div v-if="!allProducts.length && !isFetchingProducts" class="p-4 text-center text-n-slate-9 text-sm">
            No products found. Please add products first.
          </div>
        </div>
      </div>
    </div>

    <div class="flex justify-end gap-2 pt-2">
      <Button label="Cancel" variant="clear" @click="emit('cancel')" />
      <Button 
        :label="form.id ? 'Update Bundle' : 'Create Bundle'" 
        @click="handleSubmit" 
      />
    </div>
  </div>
</template>
