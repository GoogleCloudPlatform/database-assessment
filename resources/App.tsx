import Dashboard from "@/pages/Dashboard"
import { ThemeProvider } from "@/components/theme-provider"
import { Toaster } from "@/components/ui/toaster"

const App: React.FC = () => {
    return (
        <ThemeProvider defaultTheme="light" storageKey="dma-ui-theme">
            <Dashboard />
            <Toaster />
        </ThemeProvider>
    )
}

export default App
