//
//  ATParseIncrementalStore.swift
//  ATParseIncrementalStore
//
//  Created by Nicolás Landa on 12/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import os
import Parse
import CoreData
import ATParse
import ATLibrary
import ATCoreData

struct PFObjectAttributeKey {
	static let objectId = "objectId"
	static let createdAt = "createdAt"
	static let updatedAt = "updatedAt"
}

public extension Notification.Name {
	public static let ATIncrementalStoreContextDidFetchNewValuesForObject: Notification.Name = Notification.Name(rawValue: "ATIncrementalStoreContextDidFetchNewValuesForObject")
}

/**
NSIncrementalStore que conecta con un Parse Server.

Uso:

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

- Bibliografía:

    - [NSHipster](https://nshipster.com/nsincrementalstore/)
    - [andyshep](https://andyshep.org/2015/01/2015-01-10-building-basic-nsincrementalstore/)
    - [sealedabstract.com](https://sealedabstract.com/code/nsincrementalstore-the-future-of-web-services-in-ios-mac-os-x/)
    - [chris.eidhof](http://chris.eidhof.nl/post/accessing-an-api-using-coredatas-nsincrementalstore/)
    - [Apple](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/IncrementalStorePG/ImplementationStrategy/ImplementationStrategy.html)

*/
open class ATParseIncrementalStore: NSIncrementalStore {
	
	// MARK: - Properties
	
	private var cache: [NSManagedObjectID: PFObject] = [:]
	
	// MARK: - Initialization
	
	open class var storeType: String {
		return String(describing: ATParseIncrementalStore.self)
	}
	
	override open func loadMetadata() throws {
		let uuid = ProcessInfo.processInfo.globallyUniqueString
		self.metadata = [NSStoreTypeKey: ATParseIncrementalStore.storeType, NSStoreUUIDKey: uuid]
		
		os_log("Cargados metadatos con uuid %@ para %@",
			   log: .atParseIncrementalStore, type: .info, uuid, ATParseIncrementalStore.storeType)
	}
	
	// MARK: - NSIncrementalStore
	
	override open func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
		let error: NSError? = nil
		
		switch request.requestType {
		case .fetchRequestType:
			let results = try self.executeFetchRequest(request, withContext: context)
			return results
		case .saveRequestType:
			if let saveRequest = request as? NSSaveChangesRequest {
				try self.executeSaveRequest(saveRequest)
			}
			return []
		case .batchDeleteRequestType:
			break
		case .batchUpdateRequestType:
			break
		}
		
		throw error!
	}
	
	open override func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode {
		os_log("newValuesForObject %@", log: .newValuesForObject, type: .info, objectID)
		
		guard let parseObject: PFObject = self.cache[objectID] else {
			let message = "El objeto con NSManagedObjectID \(objectID) no existe en la cache"
			os_log("%@", log: .atParseIncrementalStore, type: .error, message)
			throw NSError(domain: Bundle.main.bundleIdentifier!, code: -1, userInfo: [NSLocalizedDescriptionKey: message]) }
		
		let keys: [String] = Array(objectID.entity.attributesByName.keys)
		let values = parseObject.values(for: keys)
		
		if !parseObject.isDataAvailable {
			os_log("Descargando datos de %@", log: .newValuesForObject, type: .info, parseObject)
			parseObject.fetchInBackground { _, _ in
				os_log("Descargados datos de %@", log: .newValuesForObject, type: .info, parseObject)
				// Marcar como fault para forzar a pedir de nuevo los valores a newValuesForObject
				context.refresh(context.object(with: objectID), mergeChanges: false)
				// Notificar
				self.notify(context: context, newValuesWhereFetchedForObjectID: objectID)
			}
		}
		
		return NSIncrementalStoreNode(objectID: objectID, withValues: values, version: 1)
	}
	
	open override func newValue(forRelationship relationship: NSRelationshipDescription,
								forObjectWith objectID: NSManagedObjectID,
								with context: NSManagedObjectContext?) throws -> Any {
		
		guard let destinationParseObject = self.cache[objectID]?.object(forKey: relationship.name) as? PFObject,
			let destinationParseObjectId = destinationParseObject.objectId else { return NSNull() }
		
		let destinationEntity = relationship.destinationEntity!
		let destinationManagedObjectID = self.newObjectID(for: destinationEntity, referenceObject: destinationParseObjectId)
		self.cache[destinationManagedObjectID] = destinationParseObject
				
		return destinationManagedObjectID
	}
	
	open override func obtainPermanentIDs(for array: [NSManagedObject]) throws -> [NSManagedObjectID] {
		var managedObjectsIDs = [NSManagedObjectID]()
		
		let parseObjects: [PFObject] = array.map({ return PFObject(className: $0.entity.parseClassName) })
		
		do {
			try PFObject.saveAll(parseObjects)
			for (index, value) in parseObjects.enumerated() {
				let entity = array[index].entity
				let managedObjectID = self.newObjectID(for: entity, referenceObject: value.objectId!)
				managedObjectsIDs.append(managedObjectID)
			}
		} catch {
			os_log("Error al guardar los objetos Parse para obtener objectIds",
				   log: .atParseIncrementalStore, type: .error)
		}
		
		return managedObjectsIDs
	}
	
	// MARK: Identifiers Translation
	
	// MARK: Fetch
	
	func executeFetchRequest(_ request: NSPersistentStoreRequest!, withContext context: NSManagedObjectContext!) throws -> [Any] {
		var error: NSError? = nil
		guard let fetchRequest = request as? NSFetchRequest<NSFetchRequestResult> else { fatalError() }
		
		let cacheContext = self.cacheManagedObjectContext
		
		switch fetchRequest.resultType {
		case .managedObjectResultType:
			let managedObjects = self.fetchRemoteObjectsWithRequest(fetchRequest, context: context)
			return managedObjects
		case .managedObjectIDResultType:
			do {
				try cacheContext.fetch(fetchRequest)
			} catch let error as NSError {
				print("erorr fetching object ids: \(error)")
			}
			return []
		case .countResultType, .dictionaryResultType:
			do {
				return try cacheContext.fetch(fetchRequest)
			} catch let error1 as NSError {
				error = error1
				throw error!
			}
		default:
			throw error!
		}
	}
	
	// MARK: Save
	
	func executeSaveRequest(_ saveRequest: NSSaveChangesRequest) throws {
		if let insertedObjects = saveRequest.insertedObjects {
			do {
				try self.save(insertedObjects)
			} catch {
				self.delete(insertedObjects)
				throw error
			}
		}
		
		if let updatedObjects = saveRequest.updatedObjects {
			try self.save(updatedObjects)
		}
		
		if let deletedObjects = saveRequest.deletedObjects {
			self.delete(deletedObjects)
		}
	}
	
	// MARK: Others
	
	/**
	Recupera los objetos remotos asociados a la petición.
	
	- Parameter fetchRequest: La petición usada para recuperar los objetos remotos
	- Parameter context: Un contexto
	
	- Returns: Los objetos recuperados transformados en `NSManagedObject`
	*/
	func fetchRemoteObjectsWithRequest(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>, context: NSManagedObjectContext) -> [NSManagedObject] {
		guard let parseClassName = fetchRequest.entity?.parseClassName else {
			os_log("The NSManagedObject class with name %@ has no ParseClassName attribute",
				   log: .atParseIncrementalStore, type: .error, fetchRequest.entityName ?? "unknown")
			return []
		}
		
		let parseObjects = self.fetch(fromClass: parseClassName, with: fetchRequest)
		
		let parseManagedMappedObjects: [NSManagedObjectID: PFObject] =
			Dictionary(uniqueKeysWithValues: parseObjects.compactMap({ return (self.newObjectID(for: fetchRequest.entity!, referenceObject: $0.objectId!), $0) }))
		
		self.cache.merge(parseManagedMappedObjects) { (left, right) -> PFObject in
			return left.updatedAt! < right.updatedAt! ? right : left
		}
		
		let managedObjectsIDs = parseManagedMappedObjects.keys
		let managedObjects = managedObjectsIDs.compactMap({ context.object(with: $0) })
		
		return managedObjects
	}
	
	// MARK: - Parse
	
	typealias ParseFetchBlock = ([PFObject]) -> Void
	/// Recupera los objetos de forma síncrona
	///
	/// - Parameters:
	///   - className: Nombre de la clase cuyos objetos han de recuperarse
	///   - request: Petición
	private func fetch(fromClass className: String, with request: NSFetchRequest<NSFetchRequestResult>) -> [PFObject] {
		let pfQuery = PFQuery(className: className, predicate: request.predicate)
		pfQuery.skip = request.fetchOffset
		pfQuery.limit = request.fetchLimit
		pfQuery.order(by: request.sortDescriptors)
		
		if let propertiesToFetch = request.propertiesToFetch as? [String] {
			pfQuery.selectKeys(propertiesToFetch)
		}
		
		do {
			let pfObjects = try pfQuery.findObjects()
			os_log("Recuperados %d objectos de tipo %@", log: .parseFetch, type: .info, pfObjects.count, className)
			return pfObjects
		} catch {
			os_log("Ocurrió un error con la petición a Parse:\n\t%@", log: .atParseIncrementalStore, type: .error, error.localizedDescription)
			return []
		}
	}
	
	private func save(_ managedObjects: Set<NSManagedObject>) throws {
		let parseObjects = managedObjects.compactMap({ parseObject(from: $0) })
		try PFObject.saveAll(parseObjects)
	}
	
	private func delete(_ managedObjects: Set<NSManagedObject>) {
		var parseObjectsToDelete: [PFObject] = []
		for managedObject in managedObjects {
			if let parseObjectId = self.referenceObject(for: managedObject.objectID) as? String {
				let parseClassName = managedObject.entity.parseClassName
				let parseObject = PFObject(withoutDataWithClassName: parseClassName, objectId: parseObjectId)
				parseObjectsToDelete.append(parseObject)
			}
		}
		
		try? PFObject.deleteAll(parseObjectsToDelete)
	}
	
	// MARK: - Mappers
	
	private func parseObject(from managedObject: NSManagedObject) -> PFObject? {
		guard let parseObjectId = self.referenceObject(for: managedObject.objectID) as? String else {
			return nil
		}
		
		let className = managedObject.entity.parseClassName
		let parseObject = PFObject(withoutDataWithClassName: className, objectId: parseObjectId)
		
		for (key, _)  in managedObject.entity.attributesByName {
			parseObject.setProperty(managedObject.value(forKey: key), forKey: key)
		}
		
		for (key, relationshipDescription) in managedObject.entity.relationshipsByName {
			if !relationshipDescription.isToMany, let destinationEntity = relationshipDescription.destinationEntity,
				let destinationManagedObject = managedObject.value(forKey: key) as? NSManagedObject,
				let destinationParseObjectId = self.referenceObject(for: destinationManagedObject.objectID) as? String {

				let destinationParseObject = PFObject(withoutDataWithClassName: destinationEntity.parseClassName, objectId: destinationParseObjectId)
				parseObject.setObject(destinationParseObject, forKey: key)
			}
		}
		
		return parseObject
	}
	
	// MARK: - Notifications
	
	private func notify(context: NSManagedObjectContext, newValuesWhereFetchedForObjectID objectID: NSManagedObjectID) {
		let userInfo: [String: Any] = ["objectID": objectID]
		let notification = Notification(name: .ATIncrementalStoreContextDidFetchNewValuesForObject,
										object: context, userInfo: userInfo)
		NotificationCenter.default.post(notification)
	}
	
	// MARK: - Cache
	
	/// The cache of managed object ids for the backing store
	
	/// Cache de `NSManagedObjectID's` para la cache
	private let cacheObjectIDCache = NSCache<NSManagedObjectID, NSManagedObjectID>()
	
	/// El NSPersistentStoreCoordinator asociado a la cache
	lazy var cachePersistentStoreCoordinator: NSPersistentStoreCoordinator = {
		let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.augmentedModel)
		
		var error: NSError? = nil
		let storeType = NSSQLiteStoreType
		let path = ATParseIncrementalStore.storeType + ".sqlite"
		let url = Sandbox.Documents.appendingPathComponent(path)
		let options = [NSMigratePersistentStoresAutomaticallyOption: NSNumber(value: true),
					   NSInferMappingModelAutomaticallyOption: NSNumber(value: true)]
		
		do {
			try coordinator.addPersistentStore(ofType: storeType, configurationName: nil, at: url, options: options)
		} catch let error {
			abort()
		}
		
		return coordinator
	}()
	
	/// El NSManagedObjectContext para la cache
	lazy var cacheManagedObjectContext: NSManagedObjectContext = {
		let context = NSManagedObjectContext(concurrencyType: NSManagedObjectContextConcurrencyType.mainQueueConcurrencyType)
		context.persistentStoreCoordinator = self.cachePersistentStoreCoordinator
		context.retainsRegisteredObjects = true
		return context
	}()
	
	/// El modelo aumentado con los atributos base de Parse.
	/// - objectId
	/// - createdAt
	/// - updatedAt
	
	lazy var augmentedModel: NSManagedObjectModel = {
		let augmentedModel = self.persistentStoreCoordinator?.managedObjectModel.copy() as! NSManagedObjectModel
		for entity in augmentedModel.entities {
			if entity.superentity != nil {
				continue
			}
			
			let objectIdProperty = NSAttributeDescription()
			objectIdProperty.name = PFObjectAttributeKey.objectId
			objectIdProperty.attributeType = NSAttributeType.stringAttributeType
			
			if #available(iOS 11.0, *) {
				let indexDescription = NSFetchIndexElementDescription(property: objectIdProperty, collationType: .binary)
			}
			
			let createdAtProperty = NSAttributeDescription()
			createdAtProperty.name = PFObjectAttributeKey.createdAt
			createdAtProperty.attributeType = NSAttributeType.dateAttributeType
			
			let updatedAtProperty = NSAttributeDescription()
			updatedAtProperty.name = PFObjectAttributeKey.updatedAt
			updatedAtProperty.attributeType = NSAttributeType.dateAttributeType
			
			var properties = entity.properties
			properties.append(objectIdProperty)
			properties.append(createdAtProperty)
			properties.append(updatedAtProperty)
			
			entity.properties = properties
		}
		
		return augmentedModel
	}()
}
