//
//  RowCache.swift
//  ATParseIncrementalStore
//
//  Created by Nicolás Landa on 26/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import os
import CoreData

class RowCache {
	
	private var objectsInUse: [NSManagedObjectID: Int]
	private var cache: NSCache<NSManagedObjectID, NSIncrementalStoreNode>
	
	// MARK: - Init
	
	init() {
		self.objectsInUse = [:]
		self.cache = .init()
	}
	
	// MARK: - API
	
	func node(forObjectID objectID: NSManagedObjectID, withValues values: [String: Any]) -> NSIncrementalStoreNode {
		if let existingNode = self.cache.object(forKey: objectID) {
			existingNode.update(withValues: [:], version: 1)
			return existingNode
		} else {
			os_log("Creado nodo para %@", log: .rowCache, type: .info, objectID.uriRepresentation().lastPathComponent)
			let newNode = NSIncrementalStoreNode(objectID: objectID, withValues: [:], version: 1)
			self.cache.setObject(newNode, forKey: objectID)
			return newNode
		}
	}
	
	func managedObjectRegistered(withID objectID: NSManagedObjectID) {
		if var referenceCounts = self.objectsInUse[objectID] {
			// El objeto ya se está usando
			referenceCounts += 1
		} else {
			// El objeto es fault todavía
			self.objectsInUse[objectID] = 1
		}
	}
	
	func managedObjectUnregistered(withID objectID: NSManagedObjectID) {
		self.objectsInUse[objectID]! -= 1
		
		if self.objectsInUse[objectID]! == 0 {
			self.objectsInUse.removeValue(forKey: objectID)
			self.cache.removeObject(forKey: objectID)
			os_log("Eliminado nodo para %@", log: .rowCache, type: .info, objectID)
		}
	}
}
