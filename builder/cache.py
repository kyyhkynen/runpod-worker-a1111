print("Preloading interrogate models")

from webui import initialize
import modules.interrogate

initialize.initialize()
interrogator = modules.interrogate.InterrogateModels("interrogate")
interrogator.load()
interrogator.categories()

print("Preloading clip-interrogator models")

from clip_interrogator import Config, Interrogator

config = Config()
interrogator = Interrogator(config)
