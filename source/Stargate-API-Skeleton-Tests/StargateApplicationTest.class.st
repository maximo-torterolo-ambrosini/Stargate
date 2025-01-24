"
A StargateAPISkeletonTest is a test class for testing the behavior of StargateAPISkeleton
"
Class {
	#name : #StargateApplicationTest,
	#superclass : #TestCase,
	#instVars : [
		'logger',
		'application',
		'port',
		'baseUrl'
	],
	#category : #'Stargate-API-Skeleton-Tests'
}

{ #category : #accessing }
StargateApplicationTest class >> defaultTimeLimit [

	^5 minute
]

{ #category : #private }
StargateApplicationTest >> baseUrl [

	^ baseUrl
]

{ #category : #private }
StargateApplicationTest >> newClient [

	^ ZnClient new
		  beOneShot;
		  enforceHttpSuccess: true;
		  yourself
]

{ #category : #private }
StargateApplicationTest >> orderVersion1dot0dot0MediaType [

	^ 'application/vnd.stargate.order+json;version=1.0.0' asMediaType
]

{ #category : #private }
StargateApplicationTest >> petVersion1dot0dot0MediaType [

	^ 'application/vnd.stargate.pet+json;version=1.0.0' asMediaType
]

{ #category : #running }
StargateApplicationTest >> runCase [

	self shouldnt: [ super runCase ] raise: Exit
]

{ #category : #private }
StargateApplicationTest >> secret [

	^ 'secret'
]

{ #category : #running }
StargateApplicationTest >> setUp [

	super setUp.
	logger := MemoryLogger new.
	port := self freeListeningTCPPort.
	StargateApplication logsDirectory ensureCreateDirectory
]

{ #category : #private }
StargateApplicationTest >> start: aLaunchpadApplication withAll: arguments [

	String streamContents: [ :stream | 
		| context rootCommand |


		rootCommand := LaunchpadRootCommand new.
		context := LaunchpadCommandLineProcessingContext
			           handling: ( CommandLineArguments withArguments: { 
						             'launchpad'.
						             'start'.
						             aLaunchpadApplication commandName } , arguments )
			           writingTo: stream.
		self assert: ( rootCommand canHandle: ( context nextCommandLineArgumentIfNone: [ self fail ] ) ).
		rootCommand evaluateWithin: context.
		application := LaunchpadApplication currentlyRunning
		]
]

{ #category : #private }
StargateApplicationTest >> startPetStore [

	self start: PetStoreApplication withAll: { 
			'--pet-store.stargate.public-url=http://localhost:<1p>' expandMacrosWith: port.
			'--pet-store.stargate.port=<1p>' expandMacrosWith: port.
			'--pet-store.stargate.operations-secret=<1s>' expandMacrosWith: self secret }.
	baseUrl := application configuration petStore stargate publicURL
]

{ #category : #private }
StargateApplicationTest >> startSouthAmericanCurrencies [

	self start: SouthAmericanCurrenciesApplication withAll: { 
			'--stargate.public-url=http://localhost:<1p>' expandMacrosWith: port.
			'--stargate.port=<1p>' expandMacrosWith: port.
			'--stargate.operations-secret=<1s>' expandMacrosWith: self secret }.
	baseUrl := application configuration stargate publicURL
]

{ #category : #running }
StargateApplicationTest >> tearDown [

	application ifNotNil: [ :theApplication | theApplication stop ].
	super tearDown
]

{ #category : #'tests - application' }
StargateApplicationTest >> testApplicationBaselineName [

	self
		assert: PetStoreApplication applicationBaselineName equals: #BaselineOfStargate;
		assert: SouthAmericanCurrenciesApplication applicationBaselineName equals: #BaselineOfStargate
]

{ #category : #'tests - api' }
StargateApplicationTest >> testBadRequest [

	self startPetStore.
	self
		should: [ 
			self newClient
				url: self baseUrl / 'orders' asUrl;
				entity: ( ZnEntity with: '{xxxx}' ofType: self orderVersion1dot0dot0MediaType );
				post;
				response
			]
		raise: ZnHttpUnsuccessful
		withExceptionDo: [ :error | self assert: error response isBadRequest ]
]

{ #category : #'tests - api' }
StargateApplicationTest >> testConflict [

	self startPetStore.
	self newClient
		url: self baseUrl / 'orders' asUrl;
		entity:
			( ZnEntity with: '{"date":"2018-10-24T18:05:46.418Z","pet":"https://api.example.com/pets/1"}'
				  ofType: self orderVersion1dot0dot0MediaType );
		post.

	self newClient
		url: self baseUrl / 'orders/1/cancel' asUrl;
		post.

	self
		should: [ 
			self newClient
				url: self baseUrl / 'orders/1/complete' asUrl;
				post
			]
		raise: ZnHttpUnsuccessful
		withExceptionDo: [ :error | 
			self
				assert: error response isError;
				assert: error response code equals: 409
			]
]

{ #category : #'tests - api' }
StargateApplicationTest >> testCreatePet [

	| response json |

	self startPetStore.
	response := self newClient
		            url: self baseUrl / 'pets' asUrl;
		            entity:
			            ( ZnEntity with: '{"name":"Firulais","type":"dog"}'
				              ofType: self petVersion1dot0dot0MediaType );
		            setAccept: self petVersion1dot0dot0MediaType;
		            post;
		            response.

	self
		assert: response isCreated;
		assert: response location equals: ( self baseUrl / 'pets' / '1' ) asString;
		assert: response contentType equals: self petVersion1dot0dot0MediaType.

	json := NeoJSONObject fromString: response contents.
	self
		assert: json status equals: 'new';
		assert: json name equals: 'Firulais';
		assert: json type equals: 'dog';
		assert: json selfLocation equals: response location
]

{ #category : #'tests - application' }
StargateApplicationTest >> testFileReferenceToDumpStackTrace [

	| segments |

	segments := PetStoreApplication fileReferenceToDumpStackTrace asPath segments.
	self
		assert: segments size equals: 2;
		assert: segments first equals: 'logs';
		assert: (segments last beginsWith: PetStoreApplication commandName);
		assert: (segments last endsWith: '.fuel')
]

{ #category : #'tests - api' }
StargateApplicationTest >> testGetCurrencies [

	| currencies |

	self startSouthAmericanCurrencies.
	currencies := NeoJSONObject fromString: ( self newClient get: self baseUrl / 'currencies' asUrl ).

	self assert: currencies size equals: 11
]

{ #category : #'tests - api' }
StargateApplicationTest >> testGetPets [

	| json |

	self startPetStore.
	json := NeoJSONObject fromString: ( self newClient get: self baseUrl / 'pets' asUrl ).

	self
		assert: json items isEmpty;
		assert: json links size equals: 1
]

{ #category : #'tests - api' }
StargateApplicationTest >> testMethodNotAllowed [

	self startPetStore.
	self newClient
		url: self baseUrl / 'pets' asUrl;
		entity:
			( ZnEntity with: '{"name":"Firulais","type":"dog"}' ofType: self petVersion1dot0dot0MediaType );
		post.

	self should: [ self newClient put: self baseUrl / 'pets/1' asUrl contents: '' ]
		raise: ZnHttpUnsuccessful
		withExceptionDo: [ :error | 
			self
				assert: error response isError;
				assert: error response code equals: 405
			]
]

{ #category : #'tests - api' }
StargateApplicationTest >> testNotAcceptable [

	self startPetStore.
	self
		should: [ 
			self newClient
				setAccept: 'application/xml';
				get: self baseUrl / 'pets' asUrl
			]
		raise: ZnHttpUnsuccessful
		withExceptionDo: [ :error | 
			self
				assert: error response code equals: 406;
				assert: error response hasEntity
			]
]

{ #category : #'tests - api' }
StargateApplicationTest >> testNotFound [

	self startPetStore.
	self should: [ self newClient get: self baseUrl / 'pets/1' asUrl ]
		raise: ZnHttpUnsuccessful
		withExceptionDo: [ :error | self assert: error response isNotFound ]
]

{ #category : #'tests - application' }
StargateApplicationTest >> testPrintHelpOn [

	| help |

	help := String streamContents: [ :stream | PetStoreApplication printHelpOn: stream ].

	self assert: help equals: ('NAME
		pet-store [<1s>] - A RESTful API for Pet stores
SYNOPSYS
		pet-store --pet-store.stargate.public-url=%<publicURL%> --pet-store.stargate.port=%<port%> --pet-store.stargate.operations-secret=%<operationsSecret%>
PARAMETERS
		--pet-store.stargate.public-url=%<publicURL%>
			Public URL where the API is deployed. Used to create hypermedia links.
		--pet-store.stargate.port=%<port%>
			Listening port.
		--pet-store.stargate.operations-secret=%<operationsSecret%>
			Secret key for checking JWT signatures.
ENVIRONMENT
		PET_STORE__STARGATE__PUBLIC_URL
			Public URL where the API is deployed. Used to create hypermedia links.
		PET_STORE__STARGATE__PORT
			Listening port.
		PET_STORE__STARGATE__OPERATIONS_SECRET
			Secret key for checking JWT signatures.
' expandMacrosWith: PetStoreApplication version)
]

{ #category : #'tests - application' }
StargateApplicationTest >> testStackTraceDumper [

	| dumper result |

	dumper := PetStoreApplication new stackTraceDumper.

	result := [ 1 / 0 ] on: ZeroDivide
		          do: [ :zeroDivide | 
			          dumper dumpStackTraceFor: zeroDivide.
			          zeroDivide return: 5
			          ].
	self assert: result equals: 5
]

{ #category : #'tests - api' }
StargateApplicationTest >> testUnsupportedMediaType [

	self startPetStore.
	self
		should: [ 
			self newClient
				url: self baseUrl / 'pets' asUrl;
				entity: ( ZnEntity json: '{"name":"Firulais","type":"dog"}' );
				post
			]
		raise: ZnHttpUnsuccessful
		withExceptionDo: [ :error | 
			self
				assert: error response isError;
				assert: error response code equals: 415
			]
]
