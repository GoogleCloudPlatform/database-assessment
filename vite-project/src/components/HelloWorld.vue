<script setup lang="ts">
import { api } from '../api'
import { Button } from '@/components/ui/button'
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from '@/components/ui/card'
import { useToast } from '@/components/ui/toast/use-toast'
import Container from '@/components/Container.vue'

defineProps<{ msg: string }>()

const { toast } = useToast()

const log = (url: string) => {
    const response = api(url);
    console.log(response);
    toast({
        title: response.url,
        description: response.key,
      });
}
</script>

<template>
  <h1>{{ msg }}</h1>

  <div class="hidden items-start justify-center gap-6 rounded-lg p-8 md:grid lg:grid-cols-2 xl:grid-cols-3">
    <div class="col-span-2 grid items-start gap-6 lg:col-span-1">
      <Container>
        <Card>
            <CardHeader>
                <CardTitle>Card Title</CardTitle>
                <CardDescription>Card Description</CardDescription>
            </CardHeader>
            <CardContent>
                Card Content
            </CardContent>
            <CardFooter>
                Card Footer
            </CardFooter>
        </Card>
      </Container>
    </div>
    <Button variant="outline" @click="log('api/url1')">CALL API/URL1</Button>
    <Button variant="outline" @click="log('api/url2')">CALL API/URL2</Button>
  </div>

</template>
