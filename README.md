# Implémentation et test d'un environnement d'orchestration de ressources pour des applications serverless

Projet de maîtrise à l'ÉTS de Montréal. Le projet vise à implanter et tester une plateforme d'orchestration de ressources pour des applications serverless et analyser ses performances en termes de fiabilité et compléxité temporelle, ainsi qu'étudier son système d'orchestration. Plus spécifiquement, il s'agit de déployer Oracle OpenWhisk sur un cluster K8s et d'intégrer les outils Terraform pour tester différentes applications serverless.

## Structure du dépôt git

> Pour cloner ce projet la première fois il faut utiliser la commande `git clone --recursive` to download the submodules content too. If you already cloned the repo and did'nt use this command you can execute `git submodule update --init --recursive`

3 dossiers sont présents dans ce dépôt.

- [`Openwhisk`](./OpenWhisk/) contient les fonctions déployées sur la plateforme Openwhisk pour effectuer les tests et les scripts pour exécuter ces tests. Il contient aussi des fichiers Docker pour construire les images utilisées dans le projet. Ainsi qu'un submodule d'Openwhisk comportant des modifications pour un scheduler custom (depuis ce [repo](https://github.com/MatheoAtche/openwhisk/tree/custom-scheduler)).
- [`faas-profiler`](./faas-profiler/) est un outil permettant de créer des charges de travail pour Openwhisk et d'analyser les performances suite à l'exécution des fonctions. Il a été adapté à partir de [faas-profiler](https://github.com/PrincetonUniversity/faas-profiler) pour fonctionner avec un déploiement d'Openwhisk sur Kubernetes.
- [`terraform`](./terraform/) contient les fichiers Terraform permettant le déploiement de Jenkins (non utilisé pour le projet), Openwhisk et les outils de monitoring sur la plateforme Kubernetes.

**TODO** Un README présentant plus d'informations dans [`Openwhisk`](./OpenWhisk/) et [`faas-profiler`](./faas-profiler/).

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

Ce déploiement se base sur la Helm chart mise à disposition par le projet Openwhisk. Elle se trouve ici : [openwhisk-deploy-kube](https://github.com/apache/openwhisk-deploy-kube)

Si besoin, mettre à jour la `storageClass` dans le fichier [`OW-values.yml`](./terraform/OpenWhisk/OW-values.yml) à la ligne [97](https://github.com/MatheoAtche/projet-maitrise-ets/blob/1acc93ccd26bf8dc6719bfa9e38a08e65d985407/terraform/OpenWhisk/OW-values.yml#L97). Ainsi que le port utilisé à la ligne [9](https://github.com/MatheoAtche/projet-maitrise-ets/blob/1acc93ccd26bf8dc6719bfa9e38a08e65d985407/terraform/OpenWhisk/OW-values.yml#L9) et les tokens d'authentification à Openwhisk à la ligne [15](https://github.com/MatheoAtche/projet-maitrise-ets/blob/1acc93ccd26bf8dc6719bfa9e38a08e65d985407/terraform/OpenWhisk/OW-values.yml#L15).

Puis, mettre à jour dans ce même fichier les éléments nécessaires selon la configuration souhaitée.

- Par exemple l'utilisation de `affinity` et `toleration` à partir de la ligne [212](https://github.com/MatheoAtche/projet-maitrise-ets/blob/1acc93ccd26bf8dc6719bfa9e38a08e65d985407/terraform/OpenWhisk/OW-values.yml#L212) pour spécifier sur quels noeuds déployer les différents composants d'Openwhisk.
- Le choix de la `containerFactory` se fait à la ligne [148](https://github.com/MatheoAtche/projet-maitrise-ets/blob/1acc93ccd26bf8dc6719bfa9e38a08e65d985407/terraform/OpenWhisk/OW-values.yml#L148).
- Pour les `runtimes` il faut mettre à jour le nom du fichier à la ligne [73](https://github.com/MatheoAtche/projet-maitrise-ets/blob/1acc93ccd26bf8dc6719bfa9e38a08e65d985407/terraform/OpenWhisk/OW-values.yml#L73), un fichier permettant d'ajouter des conteneurs de `prewarm` est disponible dans le répertoire et se nomme [`runtimes-prewarm.json`](./terraform/OpenWhisk/openwhisk-chart/runtimes-prewarm.json).
- Et il est aussi possible de configurer le temps de rétention des conteneurs `warm` à la ligne [215](https://github.com/MatheoAtche/projet-maitrise-ets/blob/1acc93ccd26bf8dc6719bfa9e38a08e65d985407/terraform/OpenWhisk/openwhisk-chart/templates/invoker-pod.yaml#L215) du fichier [`invoker-pod.yaml`](./terraform/OpenWhisk/openwhisk-chart/templates/invoker-pod.yaml)

Une fois les configurations souhaitées effectuées, pour installer Openwhisk il suffit d'exécuter la commande suivante :

```shell
terraform apply
```

Pour redéployer après avoir mis à jour les valeurs de la helm chart, il suffit de réexécuter la même commande. Il est aussi possible d'exécuter `terraform destroy` préalablement pour supprimer Openwhisk et son namespace.

#### Function Pull Scheduling

Un configuration existe aussi pour installer Openwhisk avec le [nouveau scheduler](https://github.com/apache/openwhisk/blob/a1639f0e4d7270c9a230190ac26acb61413b6bbb/proposals/POEM-2-function-pulling-container-scheduler.md). Elle utilise une copie de la Helm Chart en cours de développement dans cette [pull request](https://github.com/apache/openwhisk-deploy-kube/pull/729) au commit [3c8a72e](https://github.com/hunhoffe/openwhisk-deploy-kube/commit/3c8a72e73f724ae941bc33a8ad72797b21725088). Pour déployer Openwhisk avec cette Helm chart contenant le nouveau scheduler il faut utiliser la commande suivante :

```shell
terraform apply -var="use_new_scheduler=true"
```

Pour l'instant le nouveau scheduler ne semble pas fonctionner sur Kubernetes, mais si le développement évolue, il suffit de mettre à jour le fichier de [valeurs](./terraform/OpenWhisk/OW-values-new-scheduler.yml) et la Helm chart dans le dossier [`openwhisk-chart-new-scheduler`](./terraform/OpenWhisk/openwhisk-chart-new-scheduler/)

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
