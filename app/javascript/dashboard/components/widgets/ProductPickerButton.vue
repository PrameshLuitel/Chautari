<script setup>
import { ref } from 'vue';
import ProductPicker from './ProductPicker.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';

const emit = defineEmits(['select']);

const showPopover = ref(false);

const onSelectProduct = (product) => {
  emit('select', product);
  showPopover.value = false;
};
</script>

<template>
  <div class="relative">
    <NextButton
      v-tooltip.top-end="'Product Inventory'"
      icon="i-lucide-package"
      slate
      faded
      sm
      @click="showPopover = !showPopover"
    />
    <div 
      v-if="showPopover" 
      class="absolute bottom-full mb-2 left-0 z-50 bg-white dark:bg-n-slate-2 border border-n-weak rounded-2xl shadow-2xl overflow-hidden animate-in fade-in slide-in-from-bottom-2 duration-200"
    >
      <ProductPicker :on-select="onSelectProduct" />
    </div>
  </div>
</template>
