<script setup>
import { ref, onMounted } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';
import SettingsLayout from '../settings/SettingsLayout.vue';
import BaseSettingsHeader from '../settings/components/BaseSettingsHeader.vue';
import Button from 'dashboard/components-next/button/Button.vue';
import { useAlert } from 'dashboard/composables';
import ProductBundleList from './components/ProductBundleList.vue';
import ProductBundleForm from './components/ProductBundleForm.vue';

const { accountId } = useAccount();

const activeTab = ref('products');
const products = ref([]);
const isFetching = ref(false);
const showAddProductModal = ref(false);
const showBundleModal = ref(false);
const selectedBundle = ref(null);

const fetchProducts = async () => {
  isFetching.value = true;
  try {
    const response = await window.axios.get(`/api/v1/accounts/${accountId.value}/products`);
    products.value = response.data;
  } catch (error) {
    console.error(error);
  } finally {
    isFetching.value = false;
  }
};

const newProduct = ref({
  name: '',
  description: '',
  cost: 0,
  currency: 'NRP',
  image_url: ''
});

const saveProduct = async () => {
  if (!newProduct.value.name) {
    useAlert('Product name is required');
    return;
  }
  
  try {
    const response = await window.axios.post(`/api/v1/accounts/${accountId.value}/products`, {
      product: newProduct.value
    });
    products.value.unshift(response.data);
    showAddProductModal.value = false;
    newProduct.value = { name: '', description: '', cost: 0, currency: 'NRP', image_url: '' };
    useAlert('✨ Product successfully added');
  } catch (error) {
    const errorMessage = error.response?.data?.error || 'Could not save product.';
    useAlert(`❌ ${errorMessage}`);
  }
};

const deleteProduct = async (id) => {
  if (!confirm('Are you sure you want to remove this product?')) return;
  try {
    await window.axios.delete(`/api/v1/accounts/${accountId.value}/products/${id}`);
    products.value = products.value.filter(p => p.id !== id);
    useAlert('Product removed');
  } catch (error) {
    useAlert('Could not delete product');
  }
};

const openAddBundle = () => {
  selectedBundle.value = null;
  showBundleModal.value = true;
};

const openEditBundle = (bundle) => {
  selectedBundle.value = bundle;
  showBundleModal.value = true;
};

const refreshBundles = () => {
  showBundleModal.value = false;
  // The Child component (BundleList) will handle its own refresh or we could emit from there.
  // To keep it simple, we refresh the whole page state or just let the list do its thing on mount.
  // Actually, let's use a key to force re-render or a ref to the component.
  activeTab.value = 'bundles'; 
};

onMounted(() => {
  fetchProducts();
});
</script>

<template>
  <SettingsLayout :is-loading="isFetching">
    <template #header>
      <BaseSettingsHeader
        title="Inventory Mgt"
        description="Manage your products and bundles. Shared with customers during conversations."
      >
        <template #actions>
          <Button
            v-if="activeTab === 'products'"
            icon="i-lucide-plus"
            label="Add Product"
            @click="showAddProductModal = true"
          />
          <Button
            v-else
            icon="i-lucide-package-plus"
            label="Create Bundle"
            @click="openAddBundle"
          />
        </template>
      </BaseSettingsHeader>
    </template>

    <template #body>
      <!-- Tabs -->
      <div class="flex gap-4 border-b border-n-weak mb-6">
        <button 
          class="px-4 py-2 text-sm font-medium transition-colors border-b-2"
          :class="activeTab === 'products' ? 'border-n-brand text-n-brand' : 'border-transparent text-n-slate-11 hover:text-n-slate-12'"
          @click="activeTab = 'products'"
        >
          Products
        </button>
        <button 
          class="px-4 py-2 text-sm font-medium transition-colors border-b-2"
          :class="activeTab === 'bundles' ? 'border-n-brand text-n-brand' : 'border-transparent text-n-slate-11 hover:text-n-slate-12'"
          @click="activeTab = 'bundles'"
        >
          Bundles
        </button>
      </div>

      <!-- Products View -->
      <div v-if="activeTab === 'products'">
        <div v-if="!products.length && !isFetching" class="flex flex-col items-center justify-center py-20 text-n-slate-11">
          <div class="size-16 mb-4 rounded-full bg-n-alpha-3 flex items-center justify-center">
            <div class="i-lucide-package size-8 text-n-slate-11" />
          </div>
          <h2 class="text-xl font-medium text-n-slate-12 mb-2">No products yet</h2>
          <Button label="Add Product" icon="i-lucide-plus" @click="showAddProductModal = true" />
        </div>

        <div v-else class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          <div 
            v-for="product in products" 
            :key="product.id"
            class="bg-white dark:bg-n-solid-2 border border-n-weak rounded-xl overflow-hidden flex flex-col hover:shadow-md transition-shadow"
          >
            <div class="h-40 bg-n-alpha-1 relative border-b border-n-weak">
              <img v-if="product.image_url" :src="product.image_url" class="w-full h-full object-cover" />
              <div v-else class="w-full h-full flex items-center justify-center text-n-slate-9/30">
                <div class="i-lucide-image size-10" />
              </div>
              <div class="absolute top-2 right-2">
                <span class="bg-black/50 text-white text-xs font-bold px-2 py-1 rounded backdrop-blur-sm">
                  {{ product.currency }} {{ product.cost }}
                </span>
              </div>
            </div>
            <div class="p-4 flex flex-1 flex-col">
              <h3 class="font-bold text-n-slate-12 mb-1 truncate">{{ product.name }}</h3>
              <p class="text-n-slate-11 text-xs line-clamp-2 mb-4 flex-1">{{ product.description }}</p>
              <div class="flex justify-end pt-3 border-t border-n-weak">
                <Button variant="outline" color="red" size="xs" icon="i-lucide-trash-2" @click="deleteProduct(product.id)" />
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Bundles View -->
      <div v-else>
        <ProductBundleList :account-id="accountId" @add="openAddBundle" @edit="openEditBundle" />
      </div>
    </template>

    <!-- Modals -->
    <woot-modal v-model:show="showAddProductModal" :on-close="() => showAddProductModal = false">
      <div class="flex flex-col gap-6 p-6 min-w-[500px]">
        <h2 class="text-xl font-medium text-n-slate-12">Add New Product</h2>
        <div class="flex flex-col gap-4">
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-11">Name</label>
            <input v-model="newProduct.name" type="text" class="w-full px-3 py-2 bg-n-solid-1 border border-n-weak rounded-md text-sm" />
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-11">Description</label>
            <textarea v-model="newProduct.description" class="w-full px-3 py-2 bg-n-solid-1 border border-n-weak rounded-md text-sm min-h-[80px]" />
          </div>
          <div class="grid grid-cols-2 gap-4">
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-medium text-n-slate-11">Price</label>
              <input v-model.number="newProduct.cost" type="number" class="w-full px-3 py-2 bg-n-solid-1 border border-n-weak rounded-md text-sm" />
            </div>
            <div class="flex flex-col gap-1.5">
              <label class="text-sm font-medium text-n-slate-11">Currency</label>
              <select v-model="newProduct.currency" class="w-full px-3 py-2 bg-n-solid-1 border border-n-weak rounded-md text-sm">
                <option value="NPR">NPR</option>
                <option value="USD">USD</option>
              </select>
            </div>
          </div>
          <div class="flex flex-col gap-1.5">
            <label class="text-sm font-medium text-n-slate-11">Image URL</label>
            <input v-model="newProduct.image_url" type="text" placeholder="https://..." class="w-full px-3 py-2 bg-n-solid-1 border border-n-weak rounded-md text-sm" />
          </div>
        </div>
        <div class="flex justify-end gap-2">
          <Button label="Cancel" variant="clear" @click="showAddProductModal = false" />
          <Button label="Save Product" @click="saveProduct" />
        </div>
      </div>
    </woot-modal>

    <woot-modal v-model:show="showBundleModal" :on-close="() => showBundleModal = false">
      <ProductBundleForm 
        :account-id="accountId" 
        :bundle="selectedBundle || undefined" 
        @save="refreshBundles" 
        @cancel="showBundleModal = false" 
      />
    </woot-modal>
  </SettingsLayout>
</template>


<style scoped>
/* Scoped styles kept minimal as we use tailwind util classes */
</style>

