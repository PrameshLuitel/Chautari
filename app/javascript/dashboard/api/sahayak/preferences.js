/* global axios */
import ApiClient from '../ApiClient';

class SahayakPreferences extends ApiClient {
    constructor() {
        super('sahayak/preferences', { accountScoped: true });
    }

    get() {
        return axios.get(this.url);
    }

    updatePreferences(data) {
        return axios.put(this.url, data);
    }
}

export default new SahayakPreferences();
