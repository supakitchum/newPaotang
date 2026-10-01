export const useAdminSuccessAlert = () => {
  const showSuccessAlert = async (message = 'Saved successfully.') => {
    if (!import.meta.client) {
      return
    }

    const { default: Swal } = await import('sweetalert2')

    await Swal.fire({
      title: 'Success',
      text: message,
      icon: 'success',
      confirmButtonText: 'OK',
      buttonsStyling: false,
      customClass: {
        confirmButton: 'btn btn-primary btn-wave',
      },
    })
  }

  return {
    showSuccessAlert,
  }
}
