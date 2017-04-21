def model_policy_vcpe(pk):
    # TODO: this should be made in to a real model_policy
    with transaction.atomic():
        vcpe = VSGTenant.objects.select_for_update().filter(pk=pk)
        if not vcpe:
            return
        vcpe = vcpe[0]
        vcpe.manage_container()
        vcpe.manage_vrouter()
        vcpe.cleanup_orphans()

