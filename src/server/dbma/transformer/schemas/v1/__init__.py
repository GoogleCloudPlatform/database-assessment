from dbma import log
from dbma.__version__ import __version__
from dbma.config import BaseSchema
from dbma.utils.collection_helpers import CollectionFileSchema
from dbma.utils.collection_helpers import CollectionSchema as _CollectionSchema

logger = log.get_logger()


class CollectionSchema(_CollectionSchema, BaseSchema):
    top_sql: CollectionFileSchema
