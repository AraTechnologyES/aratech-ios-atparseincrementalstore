//
//  ATParseIncrementalStore.swift
//  ATParseIncrementalStore
//
//  Created by Nicolás Landa on 12/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import Parse
import CoreData
import ATParse
import ATLibrary
import ATCoreData

struct AugmentedModelAttributeKey {
	static let objectId = "objectId"
	static let createdAt = "createdAt"
	static let updatedAt = "updatedAt"
}

/**
IncrementalStore que conecta con un Parse Server.

- Bibliografía:

    - [NSHipster](https://nshipster.com/nsincrementalstore/)
    - [andyshep](https://andyshep.org/2015/01/2015-01-10-building-basic-nsincrementalstore/)
    - [sealedabstract.com](https://sealedabstract.com/code/nsincrementalstore-the-future-of-web-services-in-ios-mac-os-x/)
    - [chris.eidhof](http://chris.eidhof.nl/post/accessing-an-api-using-coredatas-nsincrementalstore/)
    - [Apple](https://developer.apple.com/library/archive/documentation/DataManagement/Conceptual/IncrementalStorePG/ImplementationStrategy/ImplementationStrategy.html)

*/
open class ATParseIncrementalStore: NSIncrementalStore {

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
			objectIdProperty.name = AugmentedModelAttributeKey.objectId
			objectIdProperty.attributeType = NSAttributeType.stringAttributeType
			let indexDescription = NSFetchIndexElementDescription(property: objectIdProperty, collationType: .binary)
			
			let createdAtProperty = NSAttributeDescription()
			createdAtProperty.name = AugmentedModelAttributeKey.createdAt
			createdAtProperty.attributeType = NSAttributeType.dateAttributeType
			
			let updatedAtProperty = NSAttributeDescription()
			updatedAtProperty.name = AugmentedModelAttributeKey.updatedAt
			updatedAtProperty.attributeType = NSAttributeType.dateAttributeType
			
			var properties = entity.properties
			properties.append(objectIdProperty)
			properties.append(createdAtProperty)
			properties.append(updatedAtProperty)
			
			entity.properties = properties
		}
		
		return augmentedModel
	}()
	
	// MARK: - Initialization
	
	open class var storeType: String {
		return String(describing: ATParseIncrementalStore.self)
	}
	
	override open func loadMetadata() throws {
		let uuid = ProcessInfo.processInfo.globallyUniqueString
		self.metadata = [NSStoreTypeKey: ATParseIncrementalStore.storeType, NSStoreUUIDKey: uuid]
	}
	
	// MARK: - Overrides NSIncrementalStore
	
	override open func execute(_ request: NSPersistentStoreRequest, with context: NSManagedObjectContext?) throws -> Any {
		let error: NSError? = nil
		
		switch request.requestType {
		case .fetchRequestType:
			return try self.executeFetchRequest(request, withContext: context)
		case .saveRequestType:
			break
		case .batchDeleteRequestType:
			break
		case .batchUpdateRequestType:
			break
		}
		
		throw error!
	}
	
	open override func newValuesForObject(with objectID: NSManagedObjectID, with context: NSManagedObjectContext) throws -> NSIncrementalStoreNode {
		let fetchRequest = NSFetchRequest<NSDictionary>(entityName: objectID.entity.name!)
		fetchRequest.resultType = NSFetchRequestResultType.dictionaryResultType
		fetchRequest.fetchLimit = 1
		fetchRequest.includesSubentities = false
		
		guard let parseObjectId = self.referenceObject(for: objectID) as? String else {
			fatalError("Objeto no construido con esta tienda")
		}
		
		let predicate = NSPredicate(format: "%K = %@", AugmentedModelAttributeKey.objectId, parseObjectId)
		fetchRequest.predicate = predicate
		
		var results: [AnyObject]? = nil
		let cacheContext = self.cacheManagedObjectContext
		cacheContext.performAndWait {
			do { results = try cacheContext.fetch(fetchRequest) } catch { }
		}
		
		let values = results?.last as? [String: AnyObject] ?? [:]
		let node = NSIncrementalStoreNode(objectID: objectID, withValues: values, version: 1)
		return node
	}
	
	// MARK: - Identifiers Translation
	
	// MARK: - Private
	
	/**
	Ejecuta una consulta en el contexto
	
	- Parameter request: Consulta
	- Parameter context: Contexto en el que ejecutar la consulta
	- Throws: NSError
	
	- Returns: An optional array of managed objects
	*/
	func executeFetchRequest(_ request: NSPersistentStoreRequest!, withContext context: NSManagedObjectContext!) throws -> [AnyObject] {
		var error: NSError? = nil
		guard let fetchRequest = request as? NSFetchRequest<NSFetchRequestResult> else { fatalError() }
		
		let cacheContext = self.cacheManagedObjectContext
		
		switch fetchRequest.resultType {
		case .managedObjectResultType:
			self.fetchRemoteObjectsWithRequest(fetchRequest, context: context)
			
			/// Petición copia pero a cache
			let cacheFetchRequest = request.copy() as! NSFetchRequest<NSFetchRequestResult>
			cacheFetchRequest.entity = NSEntityDescription.entity(forEntityName: fetchRequest.entityName!, in: cacheContext)
			cacheFetchRequest.resultType = NSFetchRequestResultType()
			// Solo recuperamos los id's
			cacheFetchRequest.propertiesToFetch = [AugmentedModelAttributeKey.objectId]
			
			/// Resultados de la búsqueda en cache
			let resultsFromCache = (try! cacheContext.fetch(cacheFetchRequest)) as NSArray
			
			/// Identificadores de los objetos en Parse encontrados en la cache
			let parseObjectIds = resultsFromCache.value(forKeyPath: AugmentedModelAttributeKey.objectId) as! [String]
			
			let managedObjects = parseObjectIds.map({ (parseObjectId: String) -> NSManagedObject in
				// Búsqueda de los objetos en el contexto principal
				
				/// `ObjectID` del `NSManagedObject` en el contexto principal
				let objectIDFromMainContext = self.objectIDForEntity(fetchRequest.entity!, withParseObjectId: parseObjectId)
				
				/// `NSManagedObject`del contexto principal
				let managedObjectFromMainContext = context.object(with: objectIDFromMainContext!)
				
				/*
					¿Ahora habría que rellenar toda la info del objeto o solo el objectId?
				*/
				
				/// Predicado para buscar el objeto en la cache
				let cachedObjectPredicate = NSPredicate(format: "%K = %@", AugmentedModelAttributeKey.objectId, parseObjectId)
				
				/// Resultado del objeto en la cache
				if let cachedObject = resultsFromCache.filtered(using: cachedObjectPredicate).first as? NSManagedObject {
					// TODO: Añadir al objeto del contexto principal la información en el objeto en cache
					managedObjectFromMainContext.fill(with: cachedObject)
				}
				
				return managedObjectFromMainContext
			})
			
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
	
	/**
	Recupera los objetos remotos asociados a la petición. Los objetos recuperados serán insertados o
	actualizados en el contexto provisto y en la cache local.
	
	- Parameter fetchRequest: La petición usada para recuperar los objetos remotos
	- Parameter context: Un contexto
	*/
	func fetchRemoteObjectsWithRequest(_ fetchRequest: NSFetchRequest<NSFetchRequestResult>, context: NSManagedObjectContext) {
		guard let parseClassName = fetchRequest.entity?.parseClassName else {
			NSLog("The NSManagedObject class with name \(fetchRequest.entityName ?? "unknown") has no ParseClassName")
			return
		}
		
		self.fetch(fromClass: parseClassName, with: fetchRequest) { (objects) in
			
			context.performAndWait {
				let childContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
				childContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
				childContext.parent = context
				
				childContext.performAndWait {
					_ = self.insertOrUpdateObjects(objects, ofEntity: fetchRequest.entity!, context: childContext) {(managedObjects: [AnyObject], backingObjects: [AnyObject]) -> Void in
						
						childContext.saveOrLog()
						
						self.cacheManagedObjectContext.performAndWait {
							self.cacheManagedObjectContext.saveOrLog()
						}
						
						context.performAndWait {
							let objects = childContext.registeredObjects as NSSet
							
							objects.forEach({ (object) in
								let childObject = object as! NSManagedObject
								let parentObject = context.object(with: childObject.objectID)
								context.refresh(parentObject, mergeChanges: true)
							})
						}
					}
				}
			}
		}
	}
	
	/**
	Busca un objectID para una entidad a partir de un ObjectId de Parse
	
	- Parameter entity: Una entidad válida del modelo
	- Parameter parseObjectId: ObjectId de Parse
	
	- Returns: El objectID
	*/
	
	func objectIDForEntity(_ entity: NSEntityDescription, withParseObjectId parseObjectId: String?) -> NSManagedObjectID? {
		guard let parseObjectId = parseObjectId else { return nil }
		
		var managedObjectId: NSManagedObjectID? = nil
		
		if managedObjectId == nil {
			let referenceObject = "\(parseObjectId)"
			managedObjectId = self.newObjectID(for: entity, referenceObject: referenceObject)
		}
		
		return managedObjectId
	}
	
	/**
	Busca un objectID para una entidad a partir de un ObjectId de Parse. El objectID pertenecerá a la cache.
	
	- Parameter entity: Una entidad válida del modelo
	- Parameter identifier: ObjectId de Parse
	
	- Returns: El objectID
	*/
	func objectIDFromCacheForEntity(_ entity: NSEntityDescription, withParseObjectId parseObjectId: String?) -> NSManagedObjectID? {
		if parseObjectId == nil {
			return nil
		}
		
		let objectID = self.objectIDForEntity(entity, withParseObjectId: parseObjectId)
		var cacheObjectID = self.cacheObjectIDCache.object(forKey: objectID!)
		if cacheObjectID != nil {
			return cacheObjectID
		}
		
		let objectIDfetchRequest = NSFetchRequest<NSManagedObjectID>(entityName: entity.name!)
		objectIDfetchRequest.resultType = NSFetchRequestResultType.managedObjectIDResultType
		objectIDfetchRequest.fetchLimit = 1
		
		let predicate = NSPredicate(format: "%K = %@", AugmentedModelAttributeKey.objectId, parseObjectId!)
		objectIDfetchRequest.predicate = predicate
		
		let cacheContext = self.cacheManagedObjectContext
		cacheContext.performAndWait {
			do {
				let objectIDResult = try cacheContext.fetch(objectIDfetchRequest)
				cacheObjectID = objectIDResult.last
				
				if let cacheObjectID = cacheObjectID {
					self.cacheObjectIDCache.setObject(cacheObjectID, forKey: objectID!)
				}
			} catch let error {
				print("error executing fetch request: \(error)")
			}
		}
		
		return cacheObjectID
	}
	
	typealias InsertOrUpdateCompletion = (_ managedObjects: [NSManagedObject], _ backingObjects: [NSManagedObject]) -> Void
	/**
	Inserta o actualiza un conjunto de objetos tanto en el contexto provísto como en la cache.
	El bloque será llamado con referencias válidas a los objetos actualizados.
	
	- Parameter result: Conjunto de `NSManagedObject`
	- Parameter entity: Entidad del modelo
	- Parameter context: Contexto
	
	- Returns: Un booleano representando éxito o fracaso
	*/
	func insertOrUpdateObjects(_ parseObjects: [PFObject], ofEntity entity: NSEntityDescription, context: NSManagedObjectContext, completion: InsertOrUpdateCompletion) -> Bool {
		var mainContextObjects: [NSManagedObject] = []
		var cacheContextObjects: [NSManagedObject] = []
		
		// Para cada objeto descargado
		for parseObject in parseObjects {
			
			/// ObjectId del objeto en Parse
			let parseObjectId = parseObject.objectId
			
			/// `NSManagedObject` del objeto descargado, en el contexto cache
			var cachedObject: NSManagedObject? = nil
			
			/// `NSManagedObjectID` del objeto descargado, en el contexto cache
			let cachedObjectID = self.objectIDFromCacheForEntity(entity, withParseObjectId: parseObjectId)
			
			/// Contexto cache
			let cacheContext = self.cacheManagedObjectContext
			
			cacheContext.performAndWait {
				if let cachedObjectId = cachedObjectID {
					// Si existe objectID en el contexto cache
					do {
						// Recabar el objeto del contexto cache
						cachedObject = try cacheContext.existingObject(with: cachedObjectId)
					} catch {
						fatalError("existing object matching id not found")
					}
				} else {
					// Si no existe el objectID, insertar el objeto en el contexto cache
					cachedObject = NSEntityDescription.insertNewObject(forEntityName: entity.name!, into: cacheContext)
					if let cachedObject = cachedObject {
						do {
							// Si todo ha ido correcto, obtener el objectID permanente en el contexto cache
							try cachedObject.managedObjectContext?.obtainPermanentIDs(for: [cachedObject])
						} catch {
							fatalError("permanent object ids could not be obtained")
						}
					}
				}
			}
			
			// Establecer el parseObjectId en el objeto creado
			cachedObject?.setValue(parseObjectId, forKey: AugmentedModelAttributeKey.objectId)
			
			// Rellenar el objeto de cache con lo que viene del servidor
			cachedObject?.fill(with: parseObject)
			
			var managedObject: NSManagedObject? = nil
			context.performAndWait {
				// Esta comprobación siempre tendría que ser correcta, pues la función `objectIDForEntity` genera el identificador si no existe
				if let contextObjectID = self.objectIDForEntity(entity, withParseObjectId: parseObjectId) {
					do {
						managedObject = try context.existingObject(with: contextObjectID)
					} catch {
						NSLog("Error: \(error.localizedDescription)")
					}
				}
			}
			
			// Rellenar el objeto del contexto provisto con lo que viene del servidor
			managedObject?.fill(with: parseObject)
			
			guard managedObject != nil else {
				fatalError("managedObject should not be nil")
			}
			
			if cachedObjectID != nil {
				// Insertar el objeto en el contexto provisto
				context.insert(managedObject!)
			}
			
			if let managedObject = managedObject {
				// Agregar el objeto a la lista de objetos del contexto provisto
				mainContextObjects.append(managedObject)
			}
			
			if let cachedObject = cachedObject {
				// Agregar el objeto a la lista de objetos del contexto cache
				cacheContextObjects.append(cachedObject)
			}
		}
		
		completion(mainContextObjects, cacheContextObjects)
		
		return true
	}
	
	// MARK: - Parse
	
	typealias ParseFetchBlock = ([PFObject]) -> Void
	/// Recupera los objetos de forma asíncrona
	///
	/// - Parameters:
	///   - className: Nombre de la clase cuyos objetos han de recuperarse
	///   - request: Petición
	private func fetch(fromClass className: String, with request: NSFetchRequest<NSFetchRequestResult>, completion: @escaping ParseFetchBlock) {
		let pfQuery = PFQuery(className: className, predicate: request.predicate)
		pfQuery.skip = request.fetchOffset
		pfQuery.limit = request.fetchLimit
		
		pfQuery.findObjectsInBackground { (pfObjects, error) in
			if let nsError = error as NSError? {
				NSLog("There was an error with the request: \n\(nsError)")
			} else if let objects = pfObjects {
				completion(objects)
			}
		}
	}
}
