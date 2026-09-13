---
aliases: [Dataview, Queries]
tags: [reference]
type: reference
---

# Dataview queries (copy-paste)

[[Home|← Home]] · Needs the community plugin **Dataview** (not preconfigured, only the queries are provided).

## All hosts

```dataview
TABLE ip AS IP, role AS Role, deploy AS Deploy
FROM "wiki/10-Hosts"
WHERE type = "host"
SORT ip ASC
```

## All VMs

```dataview
TABLE ip AS IP, mem AS RAM, vcpu AS vCPU
FROM "wiki/10-Hosts"
WHERE type = "vm"
SORT ip ASC
```

## All modules

```dataview
TABLE namespace AS Namespace
FROM "wiki/20-Modules"
WHERE type = "module"
SORT file.name ASC
```

## All guides

```dataview
LIST
FROM "wiki/40-Guides"
WHERE type = "guide"
SORT file.name ASC
```

## By tag (graph companion)

```dataview
LIST FROM #nixfleet
SORT file.name ASC
```

```dataview
TASK FROM "wiki" WHERE !completed GROUP BY file.link LIMIT 20
```
