<script setup>
import { ref, onMounted, computed } from 'vue';
import { useAccount } from 'dashboard/composables/useAccount';

const props = defineProps({
  onSelect: {
    type: Function,
    required: true,
  },
});

const { accountId } = useAccount();
const products = ref([]);
const bundles = ref([]);
const isFetching = ref(false);
const searchQuery = ref('');
const activeTab = ref('products');
const selectedItems = ref([]);

const fetchItems = async () => {
  isFetching.value = true;
  try {
    const [productsRes, bundlesRes] = await Promise.all([
      window.axios.get(`/api/v1/accounts/${accountId.value}/products`),
      window.axios.get(`/api/v1/accounts/${accountId.value}/product_bundles`)
    ]);
    products.value = productsRes.data;
    bundles.value = bundlesRes.data;
  } catch (error) {
    console.error(error);
  } finally {
    isFetching.value = false;
  }
};

onMounted(() => {
  fetchItems();
});

const filteredItems = computed(() => {
  const list = activeTab.value === 'products' ? products.value : bundles.value;
  return list.filter(p => 
    p.name.toLowerCase().includes(searchQuery.value.toLowerCase())
  );
});

const toggleSelection = (item) => {
  const index = selectedItems.value.findIndex(i => i.id === item.id && i.type === activeTab.value);
  if (index > -1) {
    selectedItems.value.splice(index, 1);
  } else {
    selectedItems.value.push({ ...item, type: activeTab.value });
  }
};

const isSelected = (item) => {
  return selectedItems.value.some(i => i.id === item.id && i.type === activeTab.value);
};

const handleSend = () => {
  if (selectedItems.value.length === 1) {
    props.onSelect(selectedItems.value[0]);
  } else if (selectedItems.value.length > 1) {
    // Instant Bundle logic
    const bundleName = "Custom Selection";
    const totalCost = selectedItems.value.reduce((acc, current) => acc + (current.cost || 0), 0);
    const currency = selectedItems.value[0]?.currency || 'NPR';
    const description = selectedItems.value.map(i => `- ${i.name}`).join('\n');
    
    props.onSelect({
      name: bundleName,
      cost: totalCost,
      currency,
      description: `Instant Bundle with:\n${description}`,
      isInstantBundle: true,
      items: selectedItems.value
    });
  }
};
</script>

<template>
  <div class="product-picker-container">
    <div class="px-5 pt-5 pb-2">
      <h3 class="text-xl font-black text-n-slate-12 tracking-tight mb-4">Inventory</h3>
      
      <!-- Tabs -->
      <div class="flex gap-4 border-b border-n-weak mb-4">
        <button 
          class="pb-2 text-sm font-bold transition-colors border-b-2"
          :class="activeTab === 'products' ? 'border-n-brand text-n-brand' : 'border-transparent text-n-slate-10'"
          @click="activeTab = 'products'"
        >
          Products
        </button>
        <button 
          class="pb-2 text-sm font-bold transition-colors border-b-2"
          :class="activeTab === 'bundles' ? 'border-n-brand text-n-brand' : 'border-transparent text-n-slate-10'"
          @click="activeTab = 'bundles'"
        >
          Bundles
        </button>
      </div>

      <div class="relative group">
        <span class="i-lucide-search absolute left-3.5 top-1/2 -translate-y-1/2 size-4 text-n-slate-9 group-focus-within:text-indigo-500 transition-colors" />
        <input 
          v-model="searchQuery"
          type="text" 
          placeholder="Search items..." 
          class="picker-search-input"
        />
      </div>
    </div>
    
    <div class="picker-list custom-scrollbar">
      <div v-if="isFetching" class="py-20 flex justify-center">
        <woot-loading-state />
      </div>
      <div v-else-if="!filteredItems.length" class="py-20 text-center flex flex-col items-center gap-3">
        <div class="i-lucide-package-search size-10 text-n-slate-5" />
        <p class="text-n-slate-10 text-sm font-medium">No items found</p>
      </div>
      <button
        v-for="item in filteredItems"
        :key="item.id"
        @click="toggleSelection(item)"
        class="picker-button group"
        :class="{ 'is-selected': isSelected(item) }"
      >
        <div class="picker-image-container relative">
          <img v-if="item.image_url" :src="item.image_url" class="picker-image" />
          <span v-else class="text-xs font-bold text-n-slate-9">{{ item.name.charAt(0) }}</span>
          <div v-if="isSelected(item)" class="absolute inset-0 bg-n-brand/40 flex items-center justify-center">
            <span class="i-lucide-check size-6 text-white" />
          </div>
        </div>
        <div class="flex-1 min-w-0">
          <p class="picker-product-name">{{ item.name }}</p>
          <p class="picker-product-price">{{ item.currency }} {{ item.cost }}</p>
        </div>
      </button>
    </div>

    <!-- Action Bar if items selected -->
    <div v-if="selectedItems.length" class="p-4 border-t border-n-weak bg-n-brand/5 flex items-center justify-between animate-in fade-in slide-in-from-bottom-2">
      <div class="flex flex-col">
        <p class="text-xs font-bold text-n-brand uppercase tracking-widest">{{ selectedItems.length }} selected</p>
        <p class="text-sm font-black text-n-slate-12">Total: {{ selectedItems[0]?.currency }} {{ selectedItems.reduce((acc, i) => acc + (i.cost || 0), 0) }}</p>
      </div>
      <button 
        class="px-5 py-2 bg-n-brand text-white text-sm font-black rounded-xl hover:bg-n-brand-hover active:scale-95 transition-all shadow-lg"
        @click="handleSend"
      >
        Send to Customer
      </button>
    </div>
    
    <div v-else class="p-3 border-t border-n-weak bg-n-solid-2 text-center">
      <p class="text-[10px] font-bold text-n-slate-9 uppercase tracking-widest">Select items to share or create bundle</p>
    </div>
  </div>
</template>

<style lang="scss" scoped>
.product-picker-container {
  @apply min-w-[340px] max-h-[500px] flex flex-col bg-white dark:bg-n-solid-1 rounded-2xl overflow-hidden;
}

.picker-search-input {
  @apply w-full pl-10 pr-4 py-2.5 text-sm rounded-xl border border-n-weak bg-n-solid-2 focus:border-n-iris-9 outline-none transition-all font-medium;
}

.picker-list {
  @apply overflow-y-auto flex-1 px-3 pb-3 grid gap-1.5;
}

.picker-button {
  @apply flex items-center gap-4 p-3 rounded-xl hover:bg-n-solid-2 transition-all text-left border border-transparent hover:border-n-weak active:scale-[0.98];

  &:hover {
    @apply shadow-sm;
  }

  &.is-selected {
    @apply bg-n-brand/5 border-n-brand/20 shadow-inner;
  }
}

.picker-image-container {
  @apply size-12 rounded-xl bg-n-solid-3 flex items-center justify-center overflow-hidden shadow-inner border border-n-weak;
}

.picker-image {
  @apply w-full h-full object-cover transition-transform duration-500 group-hover:scale-110;
}

.picker-product-name {
  @apply font-bold text-n-slate-12 truncate text-sm leading-tight;
}

.picker-product-price {
  @apply text-xs text-n-iris-9 dark:text-n-iris-11 font-extrabold mt-0.5;
}

.picker-arrow {
  @apply opacity-0 group-hover:opacity-100 transition-all translate-x-1 group-hover:translate-x-0 size-8 rounded-full bg-n-iris-3 dark:bg-n-iris-7 flex items-center justify-center text-n-iris-12;
}

.custom-scrollbar {
  &::-webkit-scrollbar {
    width: 4px;
  }
  &::-webkit-scrollbar-thumb {
    @apply bg-n-slate-5 rounded-full;
  }
}
</style>
