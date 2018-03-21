from datapackage_pipelines.wrapper import ingest, spew
from datapackage_pipelines.utilities.resources import PROP_STREAMING


parameters, datapackage, resources, stats = ingest() + ({},)


stats['total noise'] = 0


def get_noise():
    for i in range(50000):
        yield {'i': i}
        stats['total noise'] += 1


datapackage["resources"] += [{'name': 'noise', 'path': 'noise.csv', PROP_STREAMING: True,
                              'schema': {'fields': [{'name': 'i', 'type': 'integer'},]}}]


spew(datapackage, [get_noise()], stats)
