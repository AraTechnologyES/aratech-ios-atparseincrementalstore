//
//  NSEntityDescription+ParseClassName.swift
//  ATParseIncrementalStore
//
//  Created by Nicolás Landa on 16/7/18.
//  Copyright © 2018 Aratech. All rights reserved.
//

import CoreData

public extension NSEntityDescription {
	
	/// La clave en el diccionario `userInfo` del `NSManagedObject` correspondiente al nombre de la clase Parse con la que la entidad debe sincronizarse.
	///
	/// Credits: [sbonami](https://github.com/sbonami/PFIncrementalStore)
	public var ATParseIncrementalStoreManagedObjectEntityParseClassName: String {
		return "ParseClassName"
	}
	
	
	/// Nombre que la clase recibe en Parse.
	public var parseClassName: String {
		return self.userInfo?[ATParseIncrementalStoreManagedObjectEntityParseClassName] as? String ?? self.managedObjectClassName
	}
}
