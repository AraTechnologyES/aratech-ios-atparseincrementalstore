# ATParseIncrementalStore

`NSIncrementalStore` para trabajar con *Parse*

## Requerimientos

Tus clases de tipo  `NSManagedObject` deben tener la propiedad `parseClassName`, o llamarse igual que las clases en *Parse*.

## Integración

```

lazy var persistentContainer: NSPersistentContainer = {

	let storeType = "ATParseIncrementalStore."+ATParseIncrementalStore.storeType
	NSPersistentStoreCoordinator.registerStoreClass(ATParseIncrementalStore.self, forStoreType: storeType)

	let container = NSPersistentContainer(name: projectName)

	let atParseIncrementalStoreDescription = NSPersistentStoreDescription()
	atParseIncrementalStoreDescription.type = storeType
	container.persistentStoreDescriptions = [atParseIncrementalStoreDescription]

	container.loadPersistentStores(completionHandler: { (storeDescription, error) in ... }
}()

```
## Relaciones

* Únicamente soporta relaciones a uno, modeladas con *Pointers* en *Parse*
