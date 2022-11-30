# Implémentation et test d'un environnement d'orchestration de ressources pour des applications serverless

Projet de maîtrise à l'ÉTS de Montréal. Le projet vise à implanter et tester une plateforme d'orchestration de ressources pour des applications serverless et analyser ses performances en termes de fiabilité et compléxité temporelle, ainsi qu'étudier son système d'orchestration. Plus spécifiquement, il s'agit de déployer Oracle OpenWhisk sur un cluster K8s et d'intégrer les outils Terraform pour tester différentes applications serverless.

## Structure du dépôt git

> Pour cloner ce projet la première fois il faut utiliser la commande `git clone --recursive` pour télécharger aussi le contenu des submodules. Si vous avez déjà cloner le repo sans cette commande, vous pouvez utiliser la commande suivante `git submodule update --init --recursive`

3 dossiers sont présents dans ce dépôt.

- [`Openwhisk`](./OpenWhisk/) contient les fonctions déployées sur la plateforme Openwhisk pour effectuer les tests et les scripts pour exécuter ces tests (Testcase3 et Testcase4). Il contient aussi des fichiers Docker pour construire les images utilisées dans le projet (custom-docker-images). Ainsi qu'un submodule d'Openwhisk comportant des modifications pour un scheduler custom (depuis ce [repo](https://github.com/MatheoAtche/openwhisk/tree/custom-scheduler)) mais qui ne fonctionne pas pour l'instant. Le submodule est accompagné de "openwhisk-scheduler" qui contient le scheduler personnalisé de Alfredo Milani, plus de détails dans le README de ce dossier.
- [`faas-profiler`](./faas-profiler/) est un outil permettant de créer des charges de travail pour Openwhisk et d'analyser les performances suite à l'exécution des fonctions. Il a été adapté à partir de [faas-profiler](https://github.com/PrincetonUniversity/faas-profiler) pour fonctionner avec un déploiement d'Openwhisk sur Kubernetes. La fonction base64 utilisée pour les tests du projet est issue de ce dossier.
- [`terraform`](./terraform/) contient les fichiers Terraform permettant le déploiement de Jenkins (non utilisé pour le projet), Openwhisk et les outils de monitoring sur la plateforme Kubernetes.

Le script `deployAllFunctions.sh` permet de déployer toutes les fonctions présentent dans le répertoire et vérifier qu'elles sont bien déployées. Celles des tests du dossier [`Openwhisk`](./OpenWhisk/) et celles incluses avec [`faas-profiler`](./faas-profiler/).

## Déploiement d'Openwhisk et des outils de Monitoring

>­­­**Prérequis** :
>
>- Installation de l'outil ligne de commande [Terraform](https://www.terraform.io/downloads)
>- Avoir un accès admin à un cluster [Kubernetes](https://github.com/kubernetes/kubernetes) fonctionel avec une version supérieure à 1.19
>- Avoir configuré sur le cluster Kubernetes un [Dynamic Volume Provisioner](https://kubernetes.io/docs/concepts/storage/dynamic-provisioning/). [OpenEBS](https://openebs.io/) a été utilisé pour ce projet.

Pour pouvoir déployer sur le cluster, Terraform a besoin des informations de connexion à Kubernetes. Pour cela il faut placer un fichier nommé `kubeconfig` dans le dossier [`terraform`](./terraform/), ce fichier contient les informations de connexion à l'API de Kubernetes. Le plus simple est de copier le contenu du fichier `~/.kube/config` s'il donne un accès administrateur au cluster.

### Installation d'Openwhisk

Il faut commencer par se placer dans le dosser [`terraform/Openwhisk`](./terraform/OpenWhisk/). Si c'est le tout premier déploiement, il faut commencer par exécuter la commande suivante :

```shell
terraform init
```

Ce ne sera pas nécessaire dans le cas d'un redéploiement pour mettre à jour la configuration par exemple.

Ce déploiement se base sur la Helm chart mise à disposition par le projet Openwhisk. Elle se trouve ici : [openwhisk-deploy-kube](https://github.com/apache/openwhisk-deploy-kube). Des fichiers y ont été ajoutés pour essayer de déployer le scheduler custom.

Plusieurs variables permettent de personnaliser le déploiement :

| Nom de la variable | Type    | Valeurs possibles          | valeurs par défaut | Description |
|--------------------|---------|----------------------------|--------------------|-------------|
| `scheduler`        | Liste   | `default`, `new`, `custom` | `default`          | Permet de choisir le mode d'orchestration d'Openwhisk, `new` correspond au function pull scheduling et `custom` utilise le travail d'Alfredo Milani rappatrié ici mais ne fonctionne pas pour l'instant |
| `containerFactory` | Liste   | `docker`, `kubernetes`     | `kubernetes`       | Permet de choir si les conteneurs pour exécuter les actions sont créés avec Docker ou Kubernetes |
| `prewarm`          | Booléen | `true`, `false`            | `false`            | Si la valeur est `true` le déploiement se fera en utilisant `runtimes-prewarm.json`|

Un fichier de valeurs est disponible pour chaque scheduler, ils sont nommés avec le schéma suivant : "OW-values-[type de scheduler]-scheduler.yml".

Si besoin, mettre à jour la `storageClass` dans les fichiers de valeurs OW-values. Ainsi que le port utilisé et les tokens d'authentification à Openwhisk.

Puis, mettre à jour dans ces mêmes fichiers les éléments nécessaires selon la configuration souhaitée.

- Par exemple l'utilisation de `affinity` et `toleration` pour spécifier sur quels noeuds déployer les différents composants d'Openwhisk.
- Et il est aussi possible de configurer le temps de rétention des conteneurs `warm` avec la valeur `invoker.idleContainerTimeout`.

Une fois les configurations souhaitées effectuées, pour installer Openwhisk il suffit d'exécuter la commande suivante :

```shell
terraform apply
```

Cette commande exécutera le déploiement avec les valeurs par défaut des variables. Pour changer la valeur des variables, un possibilité est d'ajouter l'élément suivant après `apply` (pour chaque variable à modifier) : `-var="[nom de la variable]=[valeur de la vairable]"`.

Pour redéployer après avoir mis à jour les valeurs de la helm chart, il suffit de réexécuter la même commande. Il est aussi possible d'exécuter `terraform destroy` préalablement pour supprimer Openwhisk et son namespace.

### Installation de la suite de monitoring

Comme pour Openwhisk, il faut commencer par se placer dans le dosser [`terraform/Monitoring`](./terraform/Monitoring/). Si c'est le tout premier déploiement, il faut commencer par exécuter la commande suivante :

```shell
terraform init
```

Ce ne sera pas nécessaire dans le cas d'un redéploiement pour mettre à jour la configuration par exemple.

Ce déploiement se base sur la Helm chart mise à disposition par la [communauté prometheus](https://github.com/prometheus-community). Elle se trouve ici : [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack). Cela permet de déployer une suite de monitoring très complète pour Kubernetes.

Pour modifier la configuration du déploiement il suffit de mettre à jour le fichier de valeurs : [`monitoring-values.yaml`](./terraform/Monitoring/monitoring-values.yaml)

Une fois les configurations souhaitées effectuées, pour installer la suite de monitoring il suffit d'exécuter la commande suivante :

```shell
terraform apply
```

#### Mesure de la consommation d'énergie

Il est possible d'installer un service Telegraf qui peut récupérer la consommation d'énergie du noeud grâce à Intel powerstat, mais ça ne fonctionne pas sur une machine virtuelle. Le service n'a donc pas été testé complètement.
Un fois Telegraf déployé, Prometheus communiquera avec Telegraf pour récupérer les mesures.

Pour déployer la suite de monitoring avec Telegraf il faut exécuter la commande suivante :

```shell
terraform apply -var="enable_telegraf=true"
```
