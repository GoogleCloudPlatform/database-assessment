import { Route, Routes } from "react-router-dom"
// pages imports
import Placeholder from "@/pages/Placeholder"
import Home from "@/pages/Home"
import PageNotFound from "@/pages/PageNotFound"
import { ThemeProvider } from "@/components/theme-provider"

const App: React.FC = () => {
  return (
    <ThemeProvider defaultTheme="light" storageKey="dma-ui-theme">
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/landing" element={<Placeholder />} />
        <Route path="/terms" element={<Placeholder />} />
        <Route path="/privacy" element={<Placeholder />} />
        <Route path="*" element={<PageNotFound />} />
      </Routes>
    </ThemeProvider>
  )
}

export default App
